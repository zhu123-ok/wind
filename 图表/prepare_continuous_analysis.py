"""整理连续变量正式实验结果。

这个脚本只读取 MATLAB 导出的 JSON，不修改原始实验数据。
输出的紧凑 JSON 供所有连续版图表共同使用。
"""

from __future__ import annotations

import json
import math
from pathlib import Path
from xml.etree import ElementTree

import numpy as np


ROOT = Path(__file__).resolve().parents[1]
RESULT_FILE = ROOT / "WindFLO-master" / "MATLAB" / "project" / "results_continuous" / "summary.json"
DISCRETE_FILE = ROOT / "图表" / "analysis_data.json"
OUTPUT_FILE = ROOT / "图表" / "continuous_analysis_data.json"


def nondominated_mask(values: np.ndarray) -> np.ndarray:
    """返回最小化问题的非支配解标记。"""
    keep = np.ones(len(values), dtype=bool)
    for i in range(len(values)):
        dominated = np.all(values <= values[i], axis=1) & np.any(values < values[i], axis=1)
        if np.any(dominated):
            keep[i] = False
    return keep


def sign_test(nsga: np.ndarray, ccg: np.ndarray, higher_is_better: bool) -> dict:
    """用同一随机种子的结果做精确符号检验。"""
    diff = nsga - ccg if higher_is_better else ccg - nsga
    wins = int(np.sum(diff > 0))
    losses = int(np.sum(diff < 0))
    ties = int(np.sum(diff == 0))
    n = wins + losses
    if n == 0:
        return {"wins": wins, "losses": losses, "ties": ties,
                "p_one_sided": 1.0, "p_two_sided": 1.0}
    tail = sum(math.comb(n, i) for i in range(wins, n + 1)) / (2**n)
    small = min(wins, losses)
    two_sided = min(1.0, 2 * sum(math.comb(n, i) for i in range(small + 1)) / (2**n))
    return {"wins": wins, "losses": losses, "ties": ties,
            "p_one_sided": tail, "p_two_sided": two_sided}


def read_field(scenario_file: str) -> dict:
    """读取场区尺寸和矩形障碍物。"""
    root = ElementTree.parse(Path(scenario_file)).getroot()
    width = float(root.findtext("./Parameters/Width", "7000"))
    height = float(root.findtext("./Parameters/Height", "14000"))
    obstacles = []
    for item in root.findall("./Obstacles/obstacle"):
        obstacles.append([float(item.get(k, "0")) for k in ("xmin", "ymin", "xmax", "ymax")])
    return {"width": width, "height": height, "obstacles": obstacles}


def audit_layout(layout: list, field: dict, min_distance: float) -> dict:
    """独立复核布局的边界、障碍物和最小间距。"""
    xy = np.asarray(layout, dtype=float)
    inside = ((xy[:, 0] >= 0) & (xy[:, 0] <= field["width"]) &
              (xy[:, 1] >= 0) & (xy[:, 1] <= field["height"]))
    obstacle_hits = np.zeros(len(xy), dtype=bool)
    for xmin, ymin, xmax, ymax in field["obstacles"]:
        obstacle_hits |= ((xy[:, 0] > xmin) & (xy[:, 0] < xmax) &
                          (xy[:, 1] > ymin) & (xy[:, 1] < ymax))
    diff = xy[:, None, :] - xy[None, :, :]
    distance = np.sqrt(np.sum(diff * diff, axis=2))
    np.fill_diagonal(distance, np.inf)
    actual_min = float(np.min(distance))
    return {
        "minimumDistance": actual_min,
        "boundaryViolations": int(np.sum(~inside)),
        "obstacleViolations": int(np.sum(obstacle_hits)),
        "distanceViolation": max(0.0, float(min_distance) - actual_min),
        "feasible": bool(np.all(inside) and not np.any(obstacle_hits) and
                         actual_min >= float(min_distance) - 1e-6),
    }


def metric_summary(runs: list[dict]) -> dict:
    """计算均值、标准差、相对改善和配对符号检验。"""
    output = {}
    for metric, higher in (("HV", True), ("IGD", False), ("Spacing", False),
                           ("timeSeconds", False)):
        ccg = np.asarray([r[metric] for r in runs if r["algorithm"] == "CCGDE3"], dtype=float)
        nsga = np.asarray([r[metric] for r in runs if r["algorithm"] == "NSGA2"], dtype=float)
        relative = (nsga.mean() / ccg.mean() - 1) * 100 if higher else (1 - nsga.mean() / ccg.mean()) * 100
        output[metric] = {
            "CCGDE3_mean": float(ccg.mean()),
            "CCGDE3_std": float(ccg.std(ddof=1)),
            "NSGA2_mean": float(nsga.mean()),
            "NSGA2_std": float(nsga.std(ddof=1)),
            "NSGA2_relative_improvement_percent": float(relative),
            "paired_sign_test": sign_test(nsga, ccg, higher),
        }
    for metric in ("archiveSize", "evaluations", "cacheHits"):
        ccg = np.asarray([r[metric] for r in runs if r["algorithm"] == "CCGDE3"], dtype=float)
        nsga = np.asarray([r[metric] for r in runs if r["algorithm"] == "NSGA2"], dtype=float)
        output[metric] = {
            "CCGDE3_mean": float(ccg.mean()), "CCGDE3_std": float(ccg.std(ddof=1)),
            "NSGA2_mean": float(nsga.mean()), "NSGA2_std": float(nsga.std(ddof=1)),
        }
    return output


def write_tables(data: dict) -> None:
    """写出可直接放入中文 LaTeX 报告的三线表。"""
    table1 = ROOT / "图表" / "TABLE_continuous_algorithm_comparison.tex"
    table2 = ROOT / "图表" / "TABLE_continuous_representative_solutions.tex"
    metrics = data["metrics"]
    rows = []
    for algorithm in ("CCGDE3", "NSGA2"):
        prefix = algorithm
        rows.append(
            f"{algorithm} & {metrics['HV'][prefix + '_mean']:.4f} $\\pm$ {metrics['HV'][prefix + '_std']:.4f} & "
            f"{metrics['IGD'][prefix + '_mean']:.4f} $\\pm$ {metrics['IGD'][prefix + '_std']:.4f} & "
            f"{metrics['Spacing'][prefix + '_mean']:.4f} $\\pm$ {metrics['Spacing'][prefix + '_std']:.4f} & "
            f"{metrics['timeSeconds'][prefix + '_mean']:.2f} $\\pm$ {metrics['timeSeconds'][prefix + '_std']:.2f} \\\\" 
        )
    table1.write_text(
        "\\begin{table}[H]\n\\centering\n\\caption{连续变量版算法性能对比（5次独立运行）}\n"
        "\\label{tab:continuous-comparison}\n\\begin{tabular}{lcccc}\n\\toprule\n"
        "算法 & HV$\\uparrow$ & IGD$\\downarrow$ & Spacing$\\downarrow$ & 时间/s$\\downarrow$ \\\\\n\\midrule\n"
        + "\n".join(rows) + "\n\\bottomrule\n\\end{tabular}\n\\end{table}\n",
        encoding="utf-8",
    )
    rep_rows = []
    for algorithm in ("CCGDE3", "NSGA2"):
        rep = data["representatives"][algorithm]
        rep_rows.append(
            f"{algorithm} & {rep['run']} & {rep['AEP_GWh']:.2f} & {rep['LCOE']:.6f} & "
            f"{rep['CVaR95_percent']:.2f} \\\\" 
        )
    table2.write_text(
        "\\begin{table}[H]\n\\centering\n\\caption{连续变量版代表性折中解}\n"
        "\\label{tab:continuous-representatives}\n\\begin{tabular}{lcccc}\n\\toprule\n"
        "算法 & 运行序号 & AEP/(GWh/\\text{year}) & LCOE & CVaR95/(\\%) \\\\\n\\midrule\n"
        + "\n".join(rep_rows) + "\n\\bottomrule\n\\end{tabular}\n\\end{table}\n",
        encoding="utf-8",
    )


def main() -> None:
    if not RESULT_FILE.exists():
        raise FileNotFoundError(f"正式连续实验结果不存在: {RESULT_FILE}")
    raw = json.loads(RESULT_FILE.read_text(encoding="utf-8"))
    field = read_field(raw["config"]["scenarioFile"])
    min_distance = float(raw.get("problemInfo", {}).get("minDistance", 308.0))
    compact_runs = []
    points = []
    audits = []

    for run in raw["runs"]:
        objectives = np.asarray(run["objectives"], dtype=float)
        compact_runs.append({
            "algorithm": run["algorithm"], "run": run["run"], "seed": run["seed"],
            "timeSeconds": run["timeSeconds"], "HV": run["HV"], "IGD": run["IGD"],
            "Spacing": run["Spacing"], "archiveSize": len(objectives),
            "evaluations": run.get("evaluations", raw["config"]["options"]["maxFE"]),
            "cacheHits": run.get("cacheHits", 0),
            "convergenceFE": run["convergenceFE"], "convergenceHV": run["convergenceHV"],
        })
        for index, objective in enumerate(objectives):
            layout = run["layouts"][index]
            points.append({"algorithm": run["algorithm"], "run": run["run"],
                           "seed": run["seed"], "objective": objective.tolist(),
                           "layout": layout})
            audits.append(audit_layout(layout, field, min_distance))

    objective_matrix = np.asarray([p["objective"] for p in points], dtype=float)
    front_mask = nondominated_mask(objective_matrix)
    reference_front = []
    contribution = {"CCGDE3": 0, "NSGA2": 0}
    for index in np.flatnonzero(front_mask):
        item = points[index]
        contribution[item["algorithm"]] += 1
        reference_front.append({k: item[k] for k in ("algorithm", "run", "seed", "objective")})

    front_values = objective_matrix[front_mask]
    ideal = front_values.min(axis=0)
    nadir = front_values.max(axis=0)
    scale = np.maximum(nadir - ideal, np.finfo(float).eps)
    representatives = {}
    for algorithm in ("CCGDE3", "NSGA2"):
        ids = [i for i, p in enumerate(points) if p["algorithm"] == algorithm]
        values = objective_matrix[ids]
        distance = np.linalg.norm((values - ideal) / scale, axis=1)
        chosen = points[ids[int(np.argmin(distance))]]
        f = chosen["objective"]
        representatives[algorithm] = {
            "run": chosen["run"], "seed": chosen["seed"], "objective": f,
            "AEP_GWh": -f[0] / 1e6, "LCOE": f[1], "CVaR95_percent": 100 * f[2],
            "layout": chosen["layout"], "normalizedIdealDistance": float(np.min(distance)),
        }

    metrics = metric_summary(compact_runs)
    layout_audit = {
        "layoutCount": len(audits),
        "feasibleCount": int(sum(a["feasible"] for a in audits)),
        "minimumDistanceMin": float(min(a["minimumDistance"] for a in audits)),
        "minimumDistanceMedian": float(np.median([a["minimumDistance"] for a in audits])),
        "boundaryViolationTotal": int(sum(a["boundaryViolations"] for a in audits)),
        "obstacleViolationTotal": int(sum(a["obstacleViolations"] for a in audits)),
    }

    representation_effect = {}
    if DISCRETE_FILE.exists():
        discrete = json.loads(DISCRETE_FILE.read_text(encoding="utf-8"))
        representation_effect["discrete"] = {
            metric: discrete["metrics"][metric]["NSGA2_relative_improvement_percent"]
            for metric in ("HV", "IGD", "Spacing", "timeSeconds")
        }
    representation_effect["continuous"] = {
        metric: metrics[metric]["NSGA2_relative_improvement_percent"]
        for metric in ("HV", "IGD", "Spacing", "timeSeconds")
    }

    output = {
        "source": str(RESULT_FILE), "config": raw["config"],
        "problemInfo": raw.get("problemInfo", {}), "field": field,
        "runs": compact_runs,
        "allPoints": [{k: p[k] for k in ("algorithm", "run", "seed", "objective")} for p in points],
        "referenceFront": reference_front, "referenceFrontContribution": contribution,
        "metrics": metrics, "representatives": representatives,
        "layoutAudit": layout_audit, "representationEffect": representation_effect,
    }
    OUTPUT_FILE.write_text(json.dumps(output, ensure_ascii=False, indent=2), encoding="utf-8")
    write_tables(output)
    short = {
        "metrics": metrics, "frontContribution": contribution,
        "layoutAudit": layout_audit,
        "representatives": {k: {x: v[x] for x in ("run", "seed", "AEP_GWh", "LCOE", "CVaR95_percent")}
                            for k, v in representatives.items()},
    }
    print(json.dumps(short, ensure_ascii=False, indent=2))
    print(f"Saved: {OUTPUT_FILE}")


if __name__ == "__main__":
    main()
