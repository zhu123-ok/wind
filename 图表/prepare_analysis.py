"""整理正式实验结果，生成绘图和表格共用的紧凑数据。"""

from __future__ import annotations

import json
import math
from pathlib import Path
from xml.etree import ElementTree

import numpy as np


ROOT = Path(__file__).resolve().parents[1]
RESULT_FILE = ROOT / "WindFLO-master" / "MATLAB" / "project" / "results_large_scale" / "summary.json"
OUTPUT_FILE = ROOT / "图表" / "analysis_data.json"


def nondominated_mask(values: np.ndarray) -> np.ndarray:
    """返回最小化问题的非支配解标记。"""
    keep = np.ones(len(values), dtype=bool)
    for i in range(len(values)):
        if not keep[i]:
            continue
        dominated = np.all(values <= values[i], axis=1) & np.any(values < values[i], axis=1)
        if np.any(dominated):
            keep[i] = False
    return keep


def sign_test(nsga: np.ndarray, ccg: np.ndarray, higher_is_better: bool) -> dict:
    """对同一随机种子做精确符号检验。"""
    diff = nsga - ccg if higher_is_better else ccg - nsga
    wins = int(np.sum(diff > 0))
    losses = int(np.sum(diff < 0))
    n = wins + losses
    if n == 0:
        return {"wins": 0, "losses": 0, "p_one_sided": 1.0, "p_two_sided": 1.0}
    tail = sum(math.comb(n, i) for i in range(wins, n + 1)) / (2**n)
    small = min(wins, losses)
    two_sided = min(1.0, 2 * sum(math.comb(n, i) for i in range(small + 1)) / (2**n))
    return {
        "wins": wins,
        "losses": losses,
        "p_one_sided": tail,
        "p_two_sided": two_sided,
    }


def read_field_size(scenario_file: str) -> dict:
    path = Path(scenario_file).resolve()
    root = ElementTree.parse(path).getroot()
    width = float(root.findtext("./Parameters/Width", "7000"))
    height = float(root.findtext("./Parameters/Height", "14000"))
    obstacles = []
    for item in root.findall("./Obstacles/obstacle"):
        obstacles.append([float(item.get(k, "0")) for k in ("xmin", "ymin", "xmax", "ymax")])
    return {"width": width, "height": height, "obstacles": obstacles}


def main() -> None:
    raw = json.loads(RESULT_FILE.read_text(encoding="utf-8"))
    runs = raw["runs"]
    algorithms = ["CCGDE3", "NSGA2"]

    compact_runs = []
    points = []
    for run in runs:
        objectives = np.asarray(run["objectives"], dtype=float)
        layouts = run["layouts"]
        compact_runs.append({
            "algorithm": run["algorithm"],
            "run": run["run"],
            "seed": run["seed"],
            "timeSeconds": run["timeSeconds"],
            "HV": run["HV"],
            "IGD": run["IGD"],
            "Spacing": run["Spacing"],
            "archiveSize": len(objectives),
            "convergenceFE": run["convergenceFE"],
            "convergenceHV": run["convergenceHV"],
        })
        for index, objective in enumerate(objectives):
            points.append({
                "algorithm": run["algorithm"],
                "run": run["run"],
                "seed": run["seed"],
                "objective": objective.tolist(),
                "layout": layouts[index],
            })

    objective_matrix = np.asarray([p["objective"] for p in points])
    front_mask = nondominated_mask(objective_matrix)
    front_indices = np.flatnonzero(front_mask)
    reference_front = []
    contribution = {name: 0 for name in algorithms}
    for index in front_indices:
        item = points[index]
        contribution[item["algorithm"]] += 1
        reference_front.append({
            "algorithm": item["algorithm"],
            "run": item["run"],
            "seed": item["seed"],
            "objective": item["objective"],
        })

    # 使用经验前沿的理想点/最差点归一化，选择距理想点最近的折中布局。
    front_values = objective_matrix[front_mask]
    ideal = front_values.min(axis=0)
    nadir = front_values.max(axis=0)
    scale = np.maximum(nadir - ideal, np.finfo(float).eps)
    representatives = {}
    for algorithm in algorithms:
        ids = [i for i, p in enumerate(points) if p["algorithm"] == algorithm]
        values = objective_matrix[ids]
        distance = np.linalg.norm((values - ideal) / scale, axis=1)
        chosen = points[ids[int(np.argmin(distance))]]
        f = chosen["objective"]
        representatives[algorithm] = {
            "run": chosen["run"],
            "seed": chosen["seed"],
            "objective": f,
            "AEP_GWh": -f[0] / 1e6,
            "LCOE": f[1],
            "CVaR95_percent": 100 * f[2],
            "layout": chosen["layout"],
            "normalizedIdealDistance": float(np.min(distance)),
        }

    metrics = {}
    for metric, higher in (("HV", True), ("IGD", False), ("Spacing", False), ("timeSeconds", False)):
        ccg = np.asarray([r[metric] for r in compact_runs if r["algorithm"] == "CCGDE3"])
        nsga = np.asarray([r[metric] for r in compact_runs if r["algorithm"] == "NSGA2"])
        relative = (nsga.mean() / ccg.mean() - 1) * 100 if higher else (1 - nsga.mean() / ccg.mean()) * 100
        metrics[metric] = {
            "CCGDE3_mean": float(ccg.mean()),
            "CCGDE3_std": float(ccg.std(ddof=1)),
            "NSGA2_mean": float(nsga.mean()),
            "NSGA2_std": float(nsga.std(ddof=1)),
            "NSGA2_relative_improvement_percent": float(relative),
            "paired_sign_test": sign_test(nsga, ccg, higher),
        }

    archive_ccg = np.asarray([r["archiveSize"] for r in compact_runs if r["algorithm"] == "CCGDE3"])
    archive_nsga = np.asarray([r["archiveSize"] for r in compact_runs if r["algorithm"] == "NSGA2"])
    metrics["archiveSize"] = {
        "CCGDE3_mean": float(archive_ccg.mean()),
        "CCGDE3_std": float(archive_ccg.std(ddof=1)),
        "NSGA2_mean": float(archive_nsga.mean()),
        "NSGA2_std": float(archive_nsga.std(ddof=1)),
    }

    field = read_field_size(raw["config"]["scenarioFile"])
    output = {
        "source": str(RESULT_FILE),
        "config": raw["config"],
        "field": field,
        "runs": compact_runs,
        "allPoints": [{
            "algorithm": p["algorithm"],
            "run": p["run"],
            "seed": p["seed"],
            "objective": p["objective"],
        } for p in points],
        "referenceFront": reference_front,
        "referenceFrontContribution": contribution,
        "metrics": metrics,
        "representatives": representatives,
    }
    OUTPUT_FILE.write_text(json.dumps(output, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Saved: {OUTPUT_FILE}")
    print(json.dumps({"metrics": metrics, "frontContribution": contribution,
                      "representatives": {k: {x: v[x] for x in ("run", "seed", "AEP_GWh", "LCOE", "CVaR95_percent")}
                                          for k, v in representatives.items()}},
                     ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()

