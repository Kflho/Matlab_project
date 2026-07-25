%% Run_monitoring_loop.m  在线监测循环脚本
%  对Simulink仿真输出数据，在线计算每个步长下各计算中心的 J_{T^2,omega} 统计量（公式 (27)），
%  与卡方分布门限 J_{th,omega} 比较，验证正常状态下零误报。
%
%  依赖：
%    - Init_parameters.m（含噪声预生成）
%    - Compute_online_residuals.m
%    - Split_matrices_and_cov.m（门限计算）
%
%  输出：
%    - J_T2: 各区域各步长的 T^2 统计量矩阵
%    - alarm_flag: 报警标记（J_T2 > J_th 时触发）

clear; clc;
addpath(genpath('../../../../Common/'));
addpath(genpath('../Function/'));
addpath(genpath('../Script/'));

% ---- 加载参数与预设计结果 ----
Init_parameters;

% ---- 计算统计量门限 ----
% J_th = ...;  % 基于卡方分布计算各区域门限

% ---- 在线循环 ----
% for k = 1:T_sim
%     [r_y, r_s] = Compute_online_residuals(...);
%     计算 J_{T^2,omega}(k)（公式 (27)）
%     与 J_th 比较，记录报警
% end

% ---- 结果验收 ----
% 验证正常状态（k < k_fault）下各区域 J_T2 均低于门限
