import sqlite3
from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
QUERIES = ROOT / "sql" / "queries"
CHARTS = ROOT / "charts"

NAVY = "#1F2A44"
AMBER = "#E8A33D"
RED = "#C2463D"


def run_query(conn, name):
    return pd.read_sql((QUERIES / name).read_text(encoding="utf-8"), conn)


def decimal(value, suffix=""):
    return f"{value:.1f}".replace(".", ",") + suffix


def style(ax, title):
    ax.set_title(title, loc="left", fontsize=14, fontweight="bold", color=NAVY)
    for side in ["top", "right", "left"]:
        ax.spines[side].set_visible(False)
    ax.tick_params(colors=NAVY, labelsize=11)


conn = sqlite3.connect(ROOT / "dw.db")
segments = run_query(conn, "03_profit_by_segment.sql")
bands = run_query(conn, "04_margin_by_discount_band.sql")
conn.close()

CHARTS.mkdir(exist_ok=True)

fig, ax = plt.subplots(figsize=(7, 4.8))
profit = segments["profit"] / 1_000_000
colors = [RED if value < 0 else NAVY for value in profit]
bars = ax.barh(segments["segment_name"], profit, color=colors)
ax.invert_yaxis()
ax.axvline(0, color=NAVY, linewidth=0.8)
ax.bar_label(bars, labels=[decimal(v, " mi") for v in profit], padding=4, fontsize=11, color=NAVY)
ax.set_xlabel("Lucro (milhões)", color=NAVY)
ax.set_xlim(profit.min() - 5, profit.max() + 4)
style(ax, "Lucro por segmento")
ax.tick_params(axis="y", length=0)
fig.tight_layout()
fig.savefig(CHARTS / "profit_by_segment.png", dpi=200)

fig, ax = plt.subplots(figsize=(7, 4.8))
bars = ax.bar(bands["band_name"], bands["margin_pct"], color=AMBER, width=0.6)
ax.bar_label(bars, labels=[decimal(v, "%") for v in bands["margin_pct"]], padding=4, fontsize=11,
             color=NAVY)
ax.set_ylabel("Margem de lucro (%)", color=NAVY)
ax.set_xlabel("Faixa de desconto", color=NAVY)
ax.set_ylim(0, bands["margin_pct"].max() + 4)
style(ax, "Margem por faixa de desconto")
fig.tight_layout()
fig.savefig(CHARTS / "margin_by_discount_band.png", dpi=200)

print(f"Gráficos salvos em {CHARTS}")
plt.show()
