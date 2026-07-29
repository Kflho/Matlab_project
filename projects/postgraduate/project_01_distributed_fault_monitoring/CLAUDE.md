# Project 01 — Plant-Wide Monitoring and Fault Localization

格式规范、命名规则、文件夹结构、三文件工作流由 `scientific-research` skill 统一管理。本文件仅记录此项目的特定映射与路径。

## 三文件路径

- **Project 01 Note**: `D:\data\online\software\common\obsidian\data\projects\universiy\postgraduate\1. plant-wide monitoring and fault localization for interaction-oriented distributed systems\pg 01 note.md`
- **Project 01 参考文献**: `D:\data\online\software\common\obsidian\data\projects\universiy\postgraduate\1. plant-wide monitoring and fault localization for interaction-oriented distributed systems\pg 01 参考文献.md`
- **Project 01 Schedule**: `D:\data\online\software\common\obsidian\data\projects\universiy\postgraduate\1. plant-wide monitoring and fault localization for interaction-oriented distributed systems\pg 01 schedule.md`
- **论文文件夹**: `D:\data\local\study\projects\postgraduate\pg_01\references`

## 项目映射

| Skill 模板 | 本项目路径 |
|---|---|
| `utils/` | `../../../../../utils/` |
| `project_XX/` | `projects/postgraduate/project_01_distributed_fault_monitoring/` |
| `src/lib/` | 项目内部函数依赖 |
| `src/scripts/` | 可复用脚本（可独立运行，也可被调用） |
| `src/tests/` | 单元测试 |
| `src/main/` | 实验入口（experiment_XX_xxx.m） |
| `outputs/` | 实验产出（按 experiment_XX_xxx 分子文件夹，含 figures/、data/） |

## 路径规范

**强制规则：所有路径必须使用相对路径，禁止硬编码绝对路径（如 `D:\data\...`）。** 保证整个 `Matlab/` 文件夹移动到任意位置后脚本仍可正常运行。

### 路径添加

从 src/main/、src/scripts/、src/tests/ 等子文件夹内运行脚本时，需添加路径：

```matlab
addpath(genpath('../../../../../utils/'));   % src/main/ → src/ → project_01_distributed_fault_monitoring/ → postgraduate/ → projects/ → 仓库根 → utils/
addpath(genpath('../lib/'));
addpath(genpath('../scripts/'));
```

### 路径解析（从 src/main/、src/tests/、src/scripts/ 出发）

| 相对路径 | 解析目标 |
|---|---|
| `../../../../../utils/` | `Matlab/utils/`（仓库根工具库） |
| `../lib/` | `src/lib/`（项目内部函数） |
| `../scripts/` | `src/scripts/`（可复用脚本） |
| `../../outputs/experiment_XX_xxx/` | 实验产出目录（含 `figures/`、`data/`） |

### 读写文件

产出保存到 `../../outputs/experiment_XX_xxx/` 下对应子文件夹，禁止写到项目外路径。

```matlab
out_pic = '../../outputs/experiment_01_decentralized_residual/figures/';
out_data = '../../outputs/experiment_01_decentralized_residual/data/';
if ~exist(out_pic, 'dir'), mkdir(out_pic); end
save([out_data 'results.mat'], ...);
```

> **注意：** MATLAB 的 `addpath` 相对路径基于 `pwd`（当前工作目录），非脚本文件位置。务必从脚本所在目录运行（`cd` 到 `src/main/` / `src/tests/` / `src/scripts/` 后再执行），否则相对路径会解析错误。

## 命名规范

- **文件命名**: `snake_case`（全小写 + 下划线分隔），数字前缀 `test_01_` / `experiment_01_`
- **变量/函数命名**: 同 snake_case

## 任务进度

### 前期准备
- [x] 1. 子系统建模与参数配置（create_noise_v2, init_parameters, create_model_1）
- [x] 2. 模型等价转换（model_1_to_model_2, assemble_global_model）
- [x] 3. 分布式残差生成器离线设计（solve_luenberger_lmi, split_matrices_and_cov）
- [x] 4. 未知输入模型与递归滤波器（model_2_to_model_3_qr, recursive_joint_filter）
- [x] 5. 仿真数据生成与在线监测（start_simulation, compute_online_residuals, inject_fault）

### 测试
- [x] test_01 ~ test_09 全部完成

### 实验
- [x] experiment_01_decentralized_residual.m — 证明各计算中心可独立并行计算残差
- [x] experiment_02_zero_mean_residual.m
- [x] experiment_03_t2_detection.m
- [x] experiment_04_detectability_bound.m
- [x] experiment_05_coarse_localization.m
- [x] experiment_06_fine_localization.m
- [x] batch_experiments.m

## 运行须知

- **运行目录**：必须 `cd` 到脚本所在目录（`src/main/` 或 `src/scripts/`）再运行，否则相对 `addpath` 解析错误
- **Toolbox 依赖**：Control System Toolbox（`dlyap`）、Statistics Toolbox（`chi2inv`—若无则自动使用 `utils/chi2inv.m` fallback）、YALMIP+MOSEK（LMI 求解，无则回退 DARE）
- **单独运行**：每个实验脚本内含 `clear`，不能串联调用。`batch_experiments.m` 是仪表盘（读取已有 `results.mat`），不是自动执行器
- **格式化（必须在跑之前完成）**：写 `.m` → 运行 `fix_m_code.py <file> --apply` → AI 审查 diff（🔴`sim_w.Data` 等外部 API 属性名还原大写 / 🟡变量名变更检查 / 🟢注释专有名词保护）→ 修正 → 跑。详见 `~/.claude/skills/scientific-research/references/scripts.md`

## SKILL INITIALIZED: true
