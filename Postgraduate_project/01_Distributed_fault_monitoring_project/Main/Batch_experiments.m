%% Batch_experiments.m  批量实验总控脚本
%  贯穿整个仿真流程的主程序，依次调用各子函数完成：
%    1. 参数初始化与噪声预生成
%    2. 分布式残差生成器离线设计
%    3. 在线监测系统运行
%    4. 故障注入（k=500，调用 Inject_fault.m）
%    5. 两阶段故障定位
%    6. 结果绘图与可视化（统一调用 Run_visualization）
%
%  依赖：
%    - 所有 Function/ 下的函数
%    - 所有 Main/ 下的脚本

clear; clc;
addpath(genpath('../../../Common/'));
addpath(genpath('../Function/'));
addpath(genpath('../Script/'));

% ---- 1. 参数初始化 ----
Init_parameters;

% ---- 2. 噪声预生成与Simulink仿真 ----
% 调用 Create_noise_v2 预生成过程噪声 w 与测量噪声 v
% 加载或搭建 Simulink 模型，运行仿真获取 u, y, s 时间序列

% ---- 3. 离线设计：LMI 求解与矩阵拆分 ----
% A_z = Solve_luenberger_lmi(...);
% [A_z_omega, L_omega, Sigma_r_omega, Sigma_r_all] = Split_matrices_and_cov(...);

% ---- 4. 在线监测循环 ----
% Run_monitoring_loop;

% ---- 5. 故障注入 (k=500) ----
% [y, u] = Inject_fault(k_fault, y_simulink, u_simulink, 'sensor', fault_subsys, fault_mag);

% ---- 6. 粗定位（Localize_stage1_coarse）----
% Localize_stage1_coarse;

% ---- 7. 精定位（Localize_stage2_fine）----
% Localize_stage2_fine;

% ---- 8. 结果可视化 ----
% figure; plot(...); Run_visualization(gcf);
