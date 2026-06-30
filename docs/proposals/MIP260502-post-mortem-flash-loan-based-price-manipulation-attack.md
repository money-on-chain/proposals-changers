## **Post-mortem: flash Loan–based price manipulation attack on the MOC FLow Reverse Auction rBTC to MOC contract**

> :memo: `MIP#260502`

A [proposal to resolve this issue](proposal.md) is already underway.

### **Executive summary**

Since **November 12, 2025** an attacker repeatedly has executed a sandwich-style manipulation against the part of our protocol that **swaps RBTC for MOC to pay staking rewards** via Uniswap.

The attacker used a custom contract to **orchestrate multiple actions in a single transaction**, including triggering our swapper at a moment when the MOC price had been artificially pushed upward. This caused the protocol to buy MOC at an inflated price, resulting in **less value distributed to stakers** than intended.

**Total value extracted:** **0.54172521 BTC (≈ $41,731.00)**  
**Earliest observed attack:** **November 12, 2025**  
**Repeated occurrences:** Weekly (as seen in the transactions listed in Annex A)

---

## **What happened**

The attacker deployed a contract designed to coordinate both their own trades and the execution of our protocol components. Each attack followed this general pattern:

1. **Flash loan:** The attacker borrowed **RBTC** via a flash loan.
2. **Price push:** Using the borrowed RBTC, the attacker bought **MOC** on Uniswap, temporarily **driving the MOC price up**.
3. **Forced protocol buy at a bad price:** In the _same transaction_, the attacker invoked our protocol’s component that swaps **RBTC → MOC** to fund staking rewards. Because the pool price was already inflated, the protocol’s swap executed at **even worse prices** than normal.
4. **Profit \+ repayment:** The attacker then sold MOC back (capturing profit from the inflated price environment) and repaid the flash loan, keeping the difference.

Net effect: value that should have gone to **stakers** was redirected to the attacker through unfavorable execution prices during the protocol’s reward-buy swap.

---

## **Detection**

We detected the issue by observing **brief spikes in the MOC price of up to \~400%** that appeared on charts despite **no meaningful organic volume**.

These spikes were effectively “chart-visible but user-inaccessible”:

- The extreme price was present only momentarily during the attack transaction’s execution sequence.
- Normal users could not reliably trade at that price in a stable way; it existed as a short-lived state created to exploit the protocol’s swap.

This pattern was consistent with **in-transaction price manipulation** (sandwich/MEV-style behavior).

---

## **Remediation**

To address this issue, we are submitting a proposal to update **all components that trade on Uniswap** (whether buying or selling **MOC** or **RIF**) so they are protected against sandwich-style manipulation.

The core change is to replace reliance on the pool’s spot price with an **average price built from the pool’s price history**, which is far harder to manipulate momentarily. By using a historical average reference, the short-lived price spikes required for this attack become ineffective or prohibitively expensive to reproduce.

---

# **Annex A — List of affected transactions**

**Total extracted across all events:** **0.54172521 BTC (≈ $41,731.00)**  
**First observed attack:** **November 12, 2025**

This list includes the date, extracted value in BTC, and the USD equivalent, in addition to the link to the transaction itself.

- **January 28, 2026** — 0.03627594 BTC ($2,794.52)  
  [https://explorer.rootstock.io/tx/0xa3d1050ed861e51d20e8d4a0594945063d2fea25dc943fbe43ae81cb99e364ec](https://explorer.rootstock.io/tx/0xa3d1050ed861e51d20e8d4a0594945063d2fea25dc943fbe43ae81cb99e364ec)
- **January 21, 2026** — 0.03844136 BTC ($2,961.33)  
  [https://explorer.rootstock.io/tx/0x954433885ba9870de78f1027b6a525ede81f70b00e3a3b24810d0f73aa938841](https://explorer.rootstock.io/tx/0x954433885ba9870de78f1027b6a525ede81f70b00e3a3b24810d0f73aa938841)
- **January 14, 2026** — 0.04909717 BTC ($3,782.20)  
  [https://explorer.rootstock.io/tx/0x373e33cab57145aee1e3c095168e619307f113be7303f4499f4e2e494a215038](https://explorer.rootstock.io/tx/0x373e33cab57145aee1e3c095168e619307f113be7303f4499f4e2e494a215038)
- **January 7, 2026** — 0.04881166 BTC ($3,760.21)  
  [https://explorer.rootstock.io/tx/0x2335de8ec5a56936555a2492e36b974ab345c03abbb5f3d5eec2501aae4d9286](https://explorer.rootstock.io/tx/0x2335de8ec5a56936555a2492e36b974ab345c03abbb5f3d5eec2501aae4d9286)
- **December 31, 2025** — 0.05723765 BTC ($4,409.30)  
  [https://explorer.rootstock.io/tx/0x13a513275a5941a55c602d98604de79b9e48be60dc68d05b0a6e60130a3468da](https://explorer.rootstock.io/tx/0x13a513275a5941a55c602d98604de79b9e48be60dc68d05b0a6e60130a3468da)
- **December 24, 2025** — 0.05057354 BTC ($3,895.93)  
  [https://explorer.rootstock.io/tx/0x39e6c81d661c4100e27af2382fc4af6fe4ed1136b487167d09b81e703847dbd6](https://explorer.rootstock.io/tx/0x39e6c81d661c4100e27af2382fc4af6fe4ed1136b487167d09b81e703847dbd6)
- **December 17, 2025** — 0.04812247 BTC ($3,707.11)  
  [https://explorer.rootstock.io/tx/0x08208737c64c3803144f916e242ea788e713701b054daf35fb7de470d4edb745](https://explorer.rootstock.io/tx/0x08208737c64c3803144f916e242ea788e713701b054daf35fb7de470d4edb745)
- **December 10, 2025** — 0.05337846 BTC ($4,112.01)  
  [https://explorer.rootstock.io/tx/0x9827d08eb242a86a7313a546c7a493712845b3d619ed31ec8cbeb4b22783ec45](https://explorer.rootstock.io/tx/0x9827d08eb242a86a7313a546c7a493712845b3d619ed31ec8cbeb4b22783ec45)
- **November 26, 2025** — 0.05188354 BTC ($3,996.85)  
  [https://explorer.rootstock.io/tx/0x9718dddc2611b491ce0e89010e37b82f6d1ea56a54668a2fb95317c55f6eafca](https://explorer.rootstock.io/tx/0x9718dddc2611b491ce0e89010e37b82f6d1ea56a54668a2fb95317c55f6eafca)
- **November 19, 2025** — 0.05047479 BTC ($3,888.33)  
  [https://explorer.rootstock.io/tx/0x70b69793bfcc51a3833d51ac7b8cf5ef990a666d43fa65de9126f320b3d726d2](https://explorer.rootstock.io/tx/0x70b69793bfcc51a3833d51ac7b8cf5ef990a666d43fa65de9126f320b3d726d2)
- **November 12, 2025** — 0.05742863 BTC ($4,424.01)  
  [https://explorer.rootstock.io/tx/0x9faaa7eb56cc7e1e09646b3d0fa77c8a812152a7aab1ae4ab36dcc55ddb51339](https://explorer.rootstock.io/tx/0x9faaa7eb56cc7e1e09646b3d0fa77c8a812152a7aab1ae4ab36dcc55ddb51339)
