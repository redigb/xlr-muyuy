# AI model evaluation (rotation explanations)

**Decision:** `openai/gpt-oss-120b` with `reasoning_effort: low` on Groq.
Configurable via `GROQ_MODEL` and `GROQ_REASONING_EFFORT`, so we can switch models without code changes.

**Method:** `scripts/eval_groq.py` sends the **exact production prompt** (`ExplicadorGroq.java`) with the **real sealed packages**
(4 zones, 43 rotations), 2 repetitions per configuration, on 2026-11-14.

- **Automatic checks:**
  - valid JSON;
  - every rotation id answered;
  - fidelity: names its own crops and no crop outside the rotation;
  - no technical numbers (scores, decimals, %);
  - mentions frost in zones with frost months;
  - explains the downside of the traditional practice.
- **Blind judges:** two different models score, from 1 to 5, agronomic accuracy, fidelity to the data, and clarity for a farmer.

| Configuration | Valid JSON | Fidelity | No tech. numbers | Frost mentioned | Judge gpt-oss-120b (acc/fid/clar) | Judge qwen (acc/fid/clar) | Latency | Output tokens | USD / 1000 regenerations* |
|---|---|---|---|---|---|---|---|---|---|
| **gpt-oss-120b · low** ✅ | **100%** | 100% | 100% | 98% | 4.8 / 4.8 / 4.2 | 3.8 / 4.0 / 4.5 | 2.3 s | 793 | $2.54 |
| gpt-oss-120b · medium | 75% ❌ | 100% | 6% | 100% | 4.7 / 4.7 / 4.7 | 4.7 / 4.7 / 4.7 | 3.5 s | 1079 | $3.12 |
| gpt-oss-20b · low | 100% | 100% | 100% | 82% | 4.5 / 4.8 / 4.8 | 3.8 / 4.0 / 4.0 | 1.3 s | 700 | $1.16 |
| gpt-oss-20b · medium | 50% ❌ | 69% | 31% | 100% | 5.0 / 5.0 / 4.5 | 4.0 / 5.0 / 3.5 | 2.1 s | 816 | $1.18 |
| qwen3.8-27b · default | 100% | 100% | 100% | 97% | 4.8 / 4.8 / 5.0 | 5.0 / 5.0 / 5.0 | 1.9 s | 672 | $14.18 |
| qwen3.8-27b · no reasoning | 100% | 100% | 100% | 49% ❌ | 4.8 / 4.8 / 4.5 | 5.0 / 5.0 / 5.0 | 2.0 s | 662 | $14.02 |

\* One regeneration = 4 zones, one call each. Prices from Groq's model docs (Nov 2026).

**Why gpt-oss-120b · low:**
- It is fully reliable: 100% valid JSON, every id answered, no invented crops or numbers.
- It reasons about the climate: frost is mentioned in 98% of explanations for zones with frost months.
- The neutral judge rates it 4.8 on accuracy, the same as Qwen.
- It is about 5.5× cheaper than Qwen, and Qwen is a *preview* model that Groq may retire without notice (as it did with `llama-3.3-70b`).

**Notes:**
- `medium` reasoning spends tokens thinking and fails to finish the JSON in 25–50% of calls.
- The Qwen judge favors its own outputs (5.0) and scores the others about 1 point lower, so we use the gpt-oss judge as the tie-breaker.
- If Groq fails or is disabled, the app still gets a deterministic template explanation. **AI never chooses or scores rotations.**
