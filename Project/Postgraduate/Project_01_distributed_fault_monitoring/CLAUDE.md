# Project 01 — Plant-Wide Monitoring and Fault Localization

格式规范、命名规则、文件夹结构、三文件工作流由 `scientific-research` skill 统一管理。本文件仅记录此项目的特定映射与路径。

## 三文件路径

- **Project 01 Note**: `D:\Data\Online\Software\Common\Obsidian\Study\Project\Universiy\研究生项目\Project 01 Plant-Wide Monitoring and Fault Localization for Interaction-Oriented Distributed Systems\Project 01 Note.md`
- **Project 01 参考文献**: `D:\Data\Online\Software\Common\Obsidian\Study\Project\Universiy\研究生项目\Project 01 Plant-Wide Monitoring and Fault Localization for Interaction-Oriented Distributed Systems\Project 01 参考文献.md`
- **Project 01 Schedule**: `D:\Data\Online\Software\Common\Obsidian\Study\Project\Universiy\研究生项目\Project 01 Plant-Wide Monitoring and Fault Localization for Interaction-Oriented Distributed Systems\Project 01 Schedule.md`

## 项目映射

| Skill 模板 | 本项目路径 |
|---|---|
| `Common/` | `../../../../Common/` |
| `Project_XX/` | `Project/Postgraduate/Project_01_distributed_fault_monitoring/` |
| `Function/` | 可复用函数（不可独立运行） |
| `Script/` | 可复用脚本（可独立运行，也可被调） |
| `Test/` | 单元测试（扁平） |
| `Main/` | 实验入口（Experiment_XX_xxx.m） |
| `Output/` | 实验产出（按 Experiment_XX_xxx 分子文件夹） |

## 路径添加

从 Main/、Script/ 等子文件夹内运行脚本时，需添加路径（四层到根）：

```matlab
addpath(genpath('../../../../Common/'));   % Script/ → Project_01/ → Postgraduate/ → Project/ → 仓库根
addpath(genpath('../Function/'));
addpath(genpath('../Script/'));
```

## 任务进度

### 前期准备
- [x] 1. 子系统建模与参数配置（Create_noise_v2, Init_parameters, Create_model_1）
- [x] 2. 模型等价转换（Model_1_to_model_2, Assemble_global_model）
- [x] 3. 分布式残差生成器离线设计（Solve_luenberger_lmi, Split_matrices_and_cov）
- [x] 4. 未知输入模型与递归滤波器（Model_2_to_model_3_qr, Recursive_joint_filter）
- [x] 5. 仿真数据生成与在线监测（Start_simulation, Compute_online_residuals, Inject_fault）

### 测试
- [x] Test_01 ~ Test_08 全部完成

### 实验
- [x] Experiment_01_decentralized_residual.m — 证明各计算中心可独立并行计算残差
- [ ] Experiment_02_zero_mean_residual.m
- [ ] Experiment_03_T2_detection.m
- [ ] Experiment_04_detectability_bound.m
- [ ] Experiment_05_coarse_localization.m
- [ ] Experiment_06_fine_localization.m
- [ ] Batch_experiments.m
