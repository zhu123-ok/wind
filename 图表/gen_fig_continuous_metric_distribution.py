"""用配对点图展示连续变量版的三个质量指标。"""

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
from 工具.plot_utils import setup_style, save_fig, PALETTE, COLORS


ROOT = Path(__file__).resolve().parents[1]


def main():
    setup_style('colorblind')
    import matplotlib.pyplot as plt

    data = json.loads((ROOT / '图表' / 'continuous_analysis_data.json').read_text(encoding='utf-8'))
    fig, axes = plt.subplots(1, 3, figsize=(11.2, 4.15))
    specs = [('HV', 'HV（越大越好）'), ('IGD', 'IGD（越小越好）'),
             ('Spacing', 'Spacing（越小越好）')]
    for panel, (ax, (metric, ylabel)) in enumerate(zip(axes, specs)):
        ccg = np.asarray([r[metric] for r in data['runs'] if r['algorithm'] == 'CCGDE3'])
        nsga = np.asarray([r[metric] for r in data['runs'] if r['algorithm'] == 'NSGA2'])
        for i in range(len(ccg)):
            better = nsga[i] > ccg[i] if metric == 'HV' else nsga[i] < ccg[i]
            ax.plot([0, 1], [ccg[i], nsga[i]],
                    color=COLORS['up'] if better else COLORS['down'],
                    linewidth=1.15, alpha=0.50, zorder=1)
        ax.scatter(np.zeros(len(ccg)), ccg, s=45, color=PALETTE[0], marker='o',
                   edgecolors='white', linewidths=0.5, zorder=3)
        ax.scatter(np.ones(len(nsga)), nsga, s=50, color=PALETTE[1], marker='^',
                   edgecolors='white', linewidths=0.5, zorder=3)
        ax.scatter([0, 1], [ccg.mean(), nsga.mean()], s=125, marker='D',
                   facecolors='white', edgecolors=[PALETTE[0], PALETTE[1]],
                   linewidths=2.0, zorder=4)
        effect = data['metrics'][metric]['NSGA2_relative_improvement_percent']
        if effect >= 0:
            winner = 'NSGA2'
            winner_effect = effect
        else:
            winner = 'CCGDE3'
            winner_effect = ((ccg.mean() / nsga.mean() - 1) * 100 if metric == 'HV'
                             else (1 - ccg.mean() / nsga.mean()) * 100)
        ax.text(0.5, 0.98, f'{winner} 相改善 {winner_effect:.1f}%',
                transform=ax.transAxes, ha='center', va='top', fontsize=9)
        ax.text(0.02, 0.05, f'({chr(97 + panel)})', transform=ax.transAxes, fontsize=10)
        ax.set_xticks([0, 1], ['CCGDE3', 'NSGA2'])
        ax.set_ylabel(ylabel)
        ax.grid(axis='y', alpha=0.16, linestyle='--', color=COLORS['grid'])
        ax.spines['top'].set_visible(False)
        ax.spines['right'].set_visible(False)
    fig.savefig(ROOT / '图表' / 'fig_continuous_metric_distribution.png', dpi=350, bbox_inches='tight')
    save_fig(fig, str(ROOT / '图表' / 'fig_continuous_metric_distribution.pdf'))


if __name__ == '__main__':
    main()
