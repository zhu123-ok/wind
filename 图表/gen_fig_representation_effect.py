"""对比离散与连续两种表示下 NSGA2 相对 CCGDE3 的改善率。"""

import os, sys, shutil
os.makedirs('工具', exist_ok=True)
for src in ['plot_utils.py']:
    for search in ['skills/shared-scripts', '../skills/shared-scripts']:
        p = os.path.join(search, src)
        if os.path.isfile(p):
            shutil.copy2(p, f'工具/{src}')
            break
sys.path.insert(0, '.')

import json
from pathlib import Path
import numpy as np
from 工具.plot_utils import setup_style, save_fig, PALETTE, PALETTE_LIGHT, COLORS


ROOT = Path(__file__).resolve().parents[1]


def main():
    setup_style('colorblind')
    import matplotlib.pyplot as plt

    data = json.loads((ROOT / '图表' / 'continuous_analysis_data.json').read_text(encoding='utf-8'))
    labels = ['HV', 'IGD', 'Spacing', '运行时间']
    keys = ['HV', 'IGD', 'Spacing', 'timeSeconds']
    discrete = np.asarray([data['representationEffect']['discrete'][k] for k in keys])
    continuous = np.asarray([data['representationEffect']['continuous'][k] for k in keys])
    y = np.arange(len(labels))
    h = 0.32
    fig, ax = plt.subplots(figsize=(8.2, 4.8))
    ax.axvspan(0, max(1.0, discrete.max(), continuous.max()) * 1.18,
               color=COLORS['up'], alpha=0.045, zorder=0)
    ax.axvspan(min(-1.0, discrete.min(), continuous.min()) * 1.18, 0,
               color=COLORS['down'], alpha=0.045, zorder=0)
    bars1 = ax.barh(y - h / 2, discrete, height=h, color=PALETTE_LIGHT[0],
                    edgecolor=PALETTE[0], linewidth=1.2, label='离散候选点表示')
    bars2 = ax.barh(y + h / 2, continuous, height=h, color=PALETTE_LIGHT[1],
                    edgecolor=PALETTE[1], linewidth=1.2, label='连续坐标表示')
    ax.axvline(0, color=COLORS['text'], linewidth=1.0)
    for bars, values, color in ((bars1, discrete, PALETTE[0]), (bars2, continuous, PALETTE[1])):
        for bar, value in zip(bars, values):
            offset = 1.2 if value >= 0 else -1.2
            ax.text(value + offset, bar.get_y() + bar.get_height() / 2,
                    f'{value:+.1f}%', va='center', ha='left' if value >= 0 else 'right',
                    color=color, fontsize=8.5)
    ax.set_yticks(y, labels)
    ax.set_xlabel('NSGA2 相对 CCGDE3 的改善率（%）')
    ax.text(0.99, 0.02, '正值：NSGA2 更好 →', transform=ax.transAxes,
            ha='right', va='bottom', fontsize=8, color=COLORS['up'])
    ax.text(0.01, 0.02, '← 负值：CCGDE3 更好', transform=ax.transAxes,
            ha='left', va='bottom', fontsize=8, color=COLORS['down'])
    ax.legend(loc='best', frameon=True, edgecolor=COLORS['grid'])
    ax.grid(axis='x', alpha=0.14, linestyle='--', color=COLORS['grid'])
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    ax.spines['left'].set_visible(False)
    ax.invert_yaxis()
    fig.savefig(ROOT / '图表' / 'fig_representation_effect.png', dpi=350, bbox_inches='tight')
    save_fig(fig, str(ROOT / '图表' / 'fig_representation_effect.pdf'))


if __name__ == '__main__':
    main()
