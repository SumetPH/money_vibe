# 10 holding_buy / holding_sell / holding_form / credit_card_bill (900–1,030 lines each)

Status: ready-for-agent

One commit per file.
- The three holding forms each define near-identical row widgets (`_BuyNumberFieldRow`, `_SellNumberFieldRow`,
  `_HoldingNumberFieldRow`, ticker/portfolio rows, `_HoldingSwitchRow`). Extract them into one
  `holding_form_rows.dart` only where they are identical; keep differing ones separate.
- `_confirmResetPeakProfitIfNeeded` exists in all three: move into `holding_form_dialogs.dart` only if the bodies are identical.
- `holding_sell_summary_card.dart` — `_SellSummaryCard`
- credit_card_bill: `credit_card_bill_hero_card.dart` (`_HeroSummaryCard`), `credit_card_bill_item_card.dart`
  (`_BillItemCard` + status badge). Keep `_recompute` in the State.
