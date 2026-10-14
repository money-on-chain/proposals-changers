#!/usr/bin/env node
// Validates docs/proposals/proposals.json, the proposal registry the dapps and
// the stable-protocol APIs read to show each on-chain proposal's MIP, title and
// content. A wrong changer address there silently disconnects a proposal from
// its votes, so this checks the registry against the markdown documents and
// the ignition deployments.
//
// Dependency-free on purpose (CI runs it without installing the hardhat
// workspace): only node built-ins plus the keccak-256 below.
//
// usage: node scripts/proposals/validate-proposals.mjs [registry.json]

import { existsSync, readdirSync, readFileSync } from "node:fs";
import { dirname, join, relative } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const PROPOSALS_DIR = join(ROOT, "docs", "proposals");
const REGISTRY = process.argv[2] || join(PROPOSALS_DIR, "proposals.json");
const DEPLOYMENTS_DIR = join(ROOT, "ignition", "deployments");

const STATUSES = ["Draft", "Published", "Withdrawn"];
const NETWORKS = ["rskMainnet", "rskTestnet"];
// Projects a proposal changes. Keep in sync with the dapps' tag labels.
const TAGS = ["doc", "usdrif", "oracles", "voting", "staking"];
const MIP_RE = /^MIP#(\d{2})(\d{2})(\d{2})$/;
const CHAIN_IDS = { rskMainnet: 30, rskTestnet: 31 };
const ADDRESS_RE = /^0x[0-9a-fA-F]{40}$/;
const ANY_ADDRESS_RE = /0x[0-9a-fA-F]{40}(?![0-9a-fA-F])/g;
const MAX_SUMMARY = 500;

const errors = new Set();
const warnings = new Set();
const error = (msg) => errors.add(msg);
const warn = (msg) => warnings.add(msg);

// --- keccak-256 (the pre-NIST padding Ethereum uses) ---------------------------

const RC = [
  0x0000000000000001n,
  0x0000000000008082n,
  0x800000000000808an,
  0x8000000080008000n,
  0x000000000000808bn,
  0x0000000080000001n,
  0x8000000080008081n,
  0x8000000000008009n,
  0x000000000000008an,
  0x0000000000000088n,
  0x0000000080008009n,
  0x000000008000000an,
  0x000000008000808bn,
  0x800000000000008bn,
  0x8000000000008089n,
  0x8000000000008003n,
  0x8000000000008002n,
  0x8000000000000080n,
  0x000000000000800an,
  0x800000008000000an,
  0x8000000080008081n,
  0x8000000000008080n,
  0x0000000080000001n,
  0x8000000080008008n,
];
// Rotation offsets, lane index x + 5y
const ROTATIONS = [
  0, 1, 62, 28, 27, 36, 44, 6, 55, 20, 3, 10, 43, 25, 39, 41, 45, 15, 21, 8, 18, 2, 61, 56, 14,
];
const MASK = (1n << 64n) - 1n;
const rotl = (v, n) => (n === 0 ? v : ((v << BigInt(n)) | (v >> BigInt(64 - n))) & MASK);

function keccakF(a) {
  for (let round = 0; round < 24; round++) {
    const c = [0, 1, 2, 3, 4].map((x) => a[x] ^ a[x + 5] ^ a[x + 10] ^ a[x + 15] ^ a[x + 20]);
    for (let x = 0; x < 5; x++) {
      const d = c[(x + 4) % 5] ^ rotl(c[(x + 1) % 5], 1);
      for (let y = 0; y < 25; y += 5) a[x + y] ^= d;
    }
    const b = new Array(25);
    for (let x = 0; x < 5; x++) {
      for (let y = 0; y < 5; y++) {
        b[y + 5 * ((2 * x + 3 * y) % 5)] = rotl(a[x + 5 * y], ROTATIONS[x + 5 * y]);
      }
    }
    for (let y = 0; y < 25; y += 5) {
      for (let x = 0; x < 5; x++) {
        a[x + y] = b[x + y] ^ (~b[((x + 1) % 5) + y] & MASK & b[((x + 2) % 5) + y]);
      }
    }
    a[0] ^= RC[round];
  }
}

function keccak256(bytes) {
  const rate = 136;
  const padded = new Uint8Array(Math.ceil((bytes.length + 1) / rate) * rate);
  padded.set(bytes);
  padded[bytes.length] ^= 0x01;
  padded[padded.length - 1] ^= 0x80;

  const state = new Array(25).fill(0n);
  for (let offset = 0; offset < padded.length; offset += rate) {
    for (let i = 0; i < rate / 8; i++) {
      let lane = 0n;
      for (let j = 7; j >= 0; j--) lane = (lane << 8n) | BigInt(padded[offset + i * 8 + j]);
      state[i] ^= lane;
    }
    keccakF(state);
  }
  let hex = "";
  for (let i = 0; i < 4; i++) {
    for (let j = 0; j < 8; j++) {
      hex += Number((state[i] >> BigInt(8 * j)) & 0xffn)
        .toString(16)
        .padStart(2, "0");
    }
  }
  return hex;
}

// EIP-55 mixed-case checksum or, given a chain id, EIP-1191: the
// chain-specific variant Rootstock wallets and explorers (Blockscout) show.
function toChecksumAddress(address, chainId) {
  const lower = address.slice(2).toLowerCase();
  const prefix = chainId === undefined ? "" : `${chainId}0x`;
  const hash = keccak256(new TextEncoder().encode(prefix + lower));
  let out = "0x";
  for (let i = 0; i < 40; i++) {
    out += parseInt(hash[i], 16) >= 8 ? lower[i].toUpperCase() : lower[i];
  }
  return out;
}

if (
  keccak256(new Uint8Array()) !==
    "c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470" ||
  toChecksumAddress("0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed") !==
    "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed" ||
  toChecksumAddress("0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed", 30) !==
    "0x5aaEB6053f3e94c9b9a09f33669435E7ef1bEAeD"
) {
  console.error("keccak-256 self-test failed");
  process.exit(2);
}

/** Error text for an address that has neither an EIP-55 checksum nor an
 * EIP-1191 one for `chainIds`; null when the checksum is valid. */
function checksumError(address, chainIds) {
  const valid = [
    toChecksumAddress(address),
    ...chainIds.map((id) => toChecksumAddress(address, id)),
  ];
  if (valid.includes(address)) return null;
  const expected = [
    `${valid[0]} (EIP-55)`,
    ...chainIds.map((id, i) => `${valid[i + 1]} (EIP-1191, chain ${id})`),
  ];
  return `${address} has an invalid checksum, expected ${expected.join(" or ")}`;
}

// --- inputs -------------------------------------------------------------------

/** Every address in ignition/deployments: lowercase -> { network, where } */
function loadDeployments() {
  const out = new Map();
  if (!existsSync(DEPLOYMENTS_DIR)) return out;
  for (const id of readdirSync(DEPLOYMENTS_DIR)) {
    const file = join(DEPLOYMENTS_DIR, id, "deployed_addresses.json");
    if (!existsSync(file)) continue;
    const network = /rsk-mainnet$|^chain-30$/.test(id)
      ? "rskMainnet"
      : /rsk-testnet$|^chain-31$/.test(id)
      ? "rskTestnet"
      : null;
    for (const [key, address] of Object.entries(JSON.parse(readFileSync(file, "utf8")))) {
      out.set(String(address).toLowerCase(), { network, where: `${id} ${key}` });
    }
  }
  return out;
}

/** Text of the first heading section mentioning "changer", up to the next
 * heading of the same or a higher level. */
function changerSection(markdown) {
  const headings = [...markdown.matchAll(/^(#{1,6})\s+(.*)$/gm)];
  const start = headings.findIndex((h) => /changer/i.test(h[2]));
  if (start === -1) return "";
  const level = headings[start][1].length;
  const next = headings.slice(start + 1).find((h) => h[1].length <= level);
  return markdown.slice(headings[start].index, next ? next.index : markdown.length);
}

function stripCode(markdown) {
  return markdown.replace(/```[\s\S]*?```/g, "").replace(/`[^`\n]*`/g, "");
}

function isValidDate(value) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const date = new Date(`${value}T00:00:00Z`);
  return !Number.isNaN(date.getTime()) && date.toISOString().startsWith(value);
}

// --- checks -------------------------------------------------------------------

let registry;
try {
  registry = JSON.parse(readFileSync(REGISTRY, "utf8"));
} catch (e) {
  console.error(`${relative(ROOT, REGISTRY)}: ${e.message}`);
  process.exit(1);
}

if (registry.schemaVersion !== 1) error("schemaVersion must be 1");
if (!Array.isArray(registry.proposals)) {
  console.error("proposals must be an array");
  process.exit(1);
}

const deployments = loadDeployments();
const readme = readFileSync(join(PROPOSALS_DIR, "README.md"), "utf8");
const seenMips = new Set();
const seenFiles = new Set();
const seenAddresses = new Map();
const seenExecutions = new Map();

for (const [index, p] of registry.proposals.entries()) {
  const at = `proposals[${index}]${p && p.mip ? ` (${p.mip})` : ""}`;
  if (!p || typeof p !== "object") {
    error(`${at}: must be an object`);
    continue;
  }

  const known = [
    "mip",
    "title",
    "tags",
    "status",
    "date",
    "summary",
    "file",
    "forumUrl",
    "changers",
  ];
  for (const key of Object.keys(p))
    if (!known.includes(key)) error(`${at}: unknown field "${key}"`);

  // mip: MIP#YYWWNN, unique, ISO week 01-53, sequence from 01
  const mip = typeof p.mip === "string" ? p.mip.match(MIP_RE) : null;
  if (!mip) {
    error(`${at}: mip must look like MIP#YYWWNN`);
  } else {
    const [, , week, seq] = mip.map(Number);
    if (week < 1 || week > 53) error(`${at}: week ${mip[2]} is not an ISO week`);
    if (seq < 1) error(`${at}: sequence must start at 01`);
    if (seenMips.has(p.mip)) error(`${at}: duplicated mip`);
    seenMips.add(p.mip);
    if (!readme.includes(p.mip)) error(`${at}: not listed in docs/proposals/README.md`);
  }

  if (typeof p.title !== "string" || !p.title.trim()) error(`${at}: title is required`);

  // tags: at least one, from TAGS, no repeats, in TAGS order
  if (!Array.isArray(p.tags) || p.tags.length === 0) {
    error(`${at}: tags must be a non-empty array of ${TAGS.join(", ")}`);
  } else {
    for (const tag of p.tags) {
      if (!TAGS.includes(tag)) error(`${at}: unknown tag "${tag}" (allowed: ${TAGS.join(", ")})`);
    }
    if (new Set(p.tags).size !== p.tags.length) error(`${at}: repeated tags`);
    const ordered = [...p.tags].sort((a, b) => TAGS.indexOf(a) - TAGS.indexOf(b));
    if (ordered.join() !== p.tags.join())
      error(`${at}: tags must follow the order ${TAGS.join(", ")}`);
  }
  if (!STATUSES.includes(p.status)) error(`${at}: status must be one of ${STATUSES.join(", ")}`);

  if (p.date !== null && (typeof p.date !== "string" || !isValidDate(p.date))) {
    error(`${at}: date must be YYYY-MM-DD or null`);
  }
  if (p.status === "Published" && !p.date) error(`${at}: a Published proposal needs its date`);

  if (p.summary !== undefined && p.summary !== null) {
    if (typeof p.summary !== "string") error(`${at}: summary must be a string`);
    else if (p.summary.length > MAX_SUMMARY) error(`${at}: summary longer than ${MAX_SUMMARY}`);
  }

  if (p.forumUrl !== null && p.forumUrl !== undefined) {
    if (
      typeof p.forumUrl !== "string" ||
      !/^https:\/\/forum\.moneyonchain\.com\/t\//.test(p.forumUrl)
    ) {
      error(`${at}: forumUrl must be a https://forum.moneyonchain.com/t/... link or null`);
    }
  }
  if (p.status === "Published" && !p.forumUrl) warn(`${at}: Published without forumUrl`);

  // file: an existing MIPYYWWNN-*.md next to the registry, mentioning its MIP
  let markdown = "";
  if (typeof p.file !== "string" || p.file.includes("/") || !p.file.endsWith(".md")) {
    error(`${at}: file must be a .md file name inside docs/proposals`);
  } else if (!existsSync(join(PROPOSALS_DIR, p.file))) {
    error(`${at}: file ${p.file} does not exist`);
  } else {
    seenFiles.add(p.file);
    markdown = readFileSync(join(PROPOSALS_DIR, p.file), "utf8");
    if (mip && !p.file.startsWith(`MIP${mip.slice(1, 4).join("")}-`)) {
      error(`${at}: file name must start with MIP${mip.slice(1, 4).join("")}-`);
    }
    if (mip && !markdown.includes(p.mip)) error(`${at}: ${p.file} does not mention ${p.mip}`);
  }

  // changers
  if (!Array.isArray(p.changers)) {
    error(`${at}: changers must be an array (empty when there is none)`);
    continue;
  }
  const documented = changerSection(markdown).toLowerCase();
  for (const [ci, changer] of p.changers.entries()) {
    const cat = `${at} changers[${ci}]`;
    const chainIds = CHAIN_IDS[changer.network] ? [CHAIN_IDS[changer.network]] : [];
    for (const key of Object.keys(changer)) {
      if (!["network", "name", "address", "submitter", "executedTx"].includes(key)) {
        error(`${cat}: unknown field "${key}"`);
      }
    }
    // submitter: the first preVote() sender (msg.sender), null until submitted
    if (changer.submitter !== null && changer.submitter !== undefined) {
      if (typeof changer.submitter !== "string" || !ADDRESS_RE.test(changer.submitter)) {
        error(`${cat}: submitter must be a 0x-prefixed 20-byte hex address or null`);
      } else {
        const problem = checksumError(changer.submitter, chainIds);
        if (problem) error(`${cat}: submitter ${problem}`);
      }
    }
    // executedTx: the acceptedStep() transaction that executed the changer,
    // null until executed (or when the indexed events already record it)
    if (changer.executedTx !== null && changer.executedTx !== undefined) {
      if (typeof changer.executedTx !== "string" || !/^0x[0-9a-f]{64}$/.test(changer.executedTx)) {
        error(
          `${cat}: executedTx must be a lowercase 0x-prefixed 32-byte transaction hash or null`,
        );
      } else {
        if (!changer.submitter) error(`${cat}: executedTx is set but submitter is null`);
        if (seenExecutions.has(changer.executedTx)) {
          error(`${cat}: executedTx already used by ${seenExecutions.get(changer.executedTx)}`);
        }
        seenExecutions.set(changer.executedTx, cat);
      }
    }
    if (!NETWORKS.includes(changer.network)) {
      error(`${cat}: network must be one of ${NETWORKS.join(", ")}`);
    }
    if (typeof changer.name !== "string" || !changer.name.trim()) error(`${cat}: name is required`);
    if (typeof changer.address !== "string" || !ADDRESS_RE.test(changer.address)) {
      error(`${cat}: address is not a 0x-prefixed 20-byte hex address`);
      continue;
    }
    const problem = checksumError(changer.address, chainIds);
    if (problem) error(`${cat}: ${problem}`);

    const lower = changer.address.toLowerCase();
    if (seenAddresses.has(lower)) {
      error(`${cat}: address already used by ${seenAddresses.get(lower)}`);
    }
    seenAddresses.set(lower, cat);

    const deployed = deployments.get(lower);
    if (deployed && deployed.network && deployed.network !== changer.network) {
      error(`${cat}: ignition deploys it on ${deployed.network} (${deployed.where})`);
    }
    if (changer.network === "rskMainnet" && markdown && !documented.includes(lower)) {
      error(`${cat}: mainnet changer is not in the "Changer Contract" section of ${p.file}`);
    }
  }
}

// Every proposal document has to be in the registry
for (const file of readdirSync(PROPOSALS_DIR)) {
  if (/^MIP\d{6}-.*\.md$/.test(file) && !seenFiles.has(file)) {
    error(`docs/proposals/${file} has no proposals.json entry`);
  }
}

// Markdown hygiene for what the dapp renders: repo images only, no raw HTML
for (const file of seenFiles) {
  const markdown = readFileSync(join(PROPOSALS_DIR, file), "utf8");
  const where = `docs/proposals/${file}`;

  for (const [, target] of markdown.matchAll(/!\[[^\]]*\]\(\s*<?([^)\s>]+)>?[^)]*\)/g)) {
    if (/^https?:/i.test(target)) {
      warn(`${where}: external image ${target} - the dapp only shows images stored in the repo`);
    } else if (!existsSync(join(PROPOSALS_DIR, decodeURI(target)))) {
      error(`${where}: image ${target} does not exist`);
    }
  }
  for (const [, target] of markdown.matchAll(
    /(?<!!)\[[^\]]*\]\(\s*<?([^)\s>#]+\.md)(#[^)\s>]*)?>?\)/g,
  )) {
    if (!/^https?:/i.test(target) && !existsSync(join(PROPOSALS_DIR, decodeURI(target)))) {
      warn(`${where}: link to ${target}, which does not exist`);
    }
  }
  if (/<\/?[a-zA-Z][a-zA-Z0-9-]*(\s[^>]*)?\/?>/.test(stripCode(markdown))) {
    warn(`${where}: contains raw HTML, which the dapp does not render`);
  }
  for (const [address] of changerSection(markdown).matchAll(ANY_ADDRESS_RE)) {
    if (/[a-f]/.test(address.slice(2)) && /[A-F]/.test(address.slice(2))) {
      const problem = checksumError(address, Object.values(CHAIN_IDS));
      if (problem) warn(`${where}: ${problem}`);
    }
  }
}

// --- report -------------------------------------------------------------------

for (const msg of warnings) console.log(`warning: ${msg}`);
for (const msg of errors) console.log(`error: ${msg}`);
console.log(
  `\n${registry.proposals.length} proposals, ${seenAddresses.size} changers: ` +
    `${errors.size} error(s), ${warnings.size} warning(s)`,
);
process.exit(errors.size ? 1 : 0);
