% batch_experiments.m
clc; close all; clear;

% ===== 添加路径（根据你的实际路径调整） =====
addpath('D:\local_data\software_data\programming_data\Matlab_project\Bachelor_thesis_simulation\Function\Create_FDIA')
addpath('D:\local_data\software_data\programming_data\Matlab_project\Bachelor_thesis_simulation\Function\Create_noise')
addpath('D:\local_data\software_data\programming_data\Matlab_project\Bachelor_thesis_simulation\Function\Create_shoukong')
addpath('D:\local_data\software_data\programming_data\Matlab_project\Bachelor_thesis_simulation\Function\Filter_design')
addpath('D:\local_data\software_data\programming_data\Matlab_project\Bachelor_thesis_simulation\Function\POMDP')
addpath('D:\local_data\software_data\programming_data\Matlab_project\Bachelor_thesis_simulation\Function')

addpath('D:\local_data\software_data\programming_data\Matlab_project\Common')
addpath('D:\local_data\software_data\programming_data\Matlab_project\Common\Plot')
addpath('D:\local_data\software_data\programming_data\Matlab_project\Common\Calculate\')
addpath('D:\local_data\software_data\programming_data\Matlab_project\Common\Visualization')
addpath('D:\local_data\software_data\programming_data\Matlab_project\Bachelor_thesis_simulation\Main\Simulink')

% ===== 实验配置列表 =====
exp_list = {};
% 
% %% 实验1：FDIA破坏实验（无水印）
% exp.name = '01_FDIA_destruction';
% exp.start_time_FDIA = 250;
% exp.FDIA_length = 750;
% exp.start_time_QW = 2000;            % 不嵌入水印
% exp.watermark_idx = 0;               % 0 表示无水印
% exp.d_target = [6.35; 6.20];
% exp.ramp_len = 100;
% exp.sign_vec = [1; 1];
% exp.plot_residual = true;
% exp.plot_liquid_level = true;
% exp.plot_residual_square = true;
% exp.plot_performance = true;
% exp.plot_attack_energy = true;
% exp.threshold_value = 1;
% exp.threshold_label = '|r|_{max}';
% exp.threshold_square_val = 0.1;
% exp.threshold_square_lbl = 'epsilon_{r}';
% exp_list{end+1} = exp;
% 
% %% 实验2：粗选水印检测（粗选弱）
% exp = exp_list{1};
% exp.name = '02_Coarse_watermark_weak';
% exp.start_time_QW = 500;
% exp.watermark_idx = 1;                % 粗选弱
% exp_list{end+1} = exp;
% 
% %% 实验3：最优弱水印检测
% exp = exp_list{1};
% exp.name = '03_Optimal_weak_watermark';
% exp.start_time_QW = 500;
% exp.watermark_idx = 3;                % 最优弱
% exp_list{end+1} = exp;
% 
% %% 实验4：最优强水印检测
% exp = exp_list{1};
% exp.name = '04_Optimal_strong_watermark';
% exp.start_time_QW = 500;
% exp.watermark_idx = 4;                % 最优强
% exp_list{end+1} = exp;
% 
% %% 实验5：攻击能量计算
% exp.name = '05_Attack_energy';
% exp.start_time_FDIA = 0;
% exp.FDIA_length = 350;
% exp.start_time_QW = 2000;
% exp.watermark_idx = 0;
% exp.d_target = [6.35;6.20];
% exp.ramp_len = 100;
% exp.sign_vec = [1; 1];
% exp.plot_residual = false;
% exp.plot_liquid_level = false;
% exp.plot_residual_square = false;
% exp.plot_performance = false;
% exp.plot_attack_energy = true;
% exp_list{end+1} = exp;
% 
% %% 实验6：性能影响参数变化图（无水印、最优弱、最优强）
% wm_idx = [0, 3, 4];
% wm_name = {'No_watermark', 'Optimal_weak', 'Optimal_strong'};
% for i = 1:length(wm_idx)
%     exp.name = ['06_Performance_', wm_name{i}];
%     exp.start_time_FDIA = 250;
%     exp.FDIA_length = 750;
%     if wm_idx(i) == 0
%         exp.start_time_QW = 2000;
%     else
%         exp.start_time_QW = 500;
%     end
%     exp.watermark_idx = wm_idx(i);
%     exp.d_target = [6.35;6.20];
%     exp.ramp_len = 100;
%     exp.sign_vec = [1; 1];
%     exp.plot_residual = false;
%     exp.plot_liquid_level = false;
%     exp.plot_residual_square = false;
%     exp.plot_performance = true;
%     exp.plot_attack_energy = false;
%     exp_list{end+1} = exp;
% end
% 
% %% 实验7：长期性能损失统计（不攻击/受攻击 × 无水印/弱/强）
% stat_wm = [0, 3, 4];
% stat_wm_names = {'NoWatermark', 'Weak', 'Strong'};
% stat_attack = {'NoAttack', 'UnderAttack'};
% stat_duration = 2000;
% for w = 1:length(stat_wm)
%     for a = 1:length(stat_attack)
%         exp.name = sprintf('07_Stats_%s_%s', stat_attack{a}, stat_wm_names{w});
%         exp.calc_stats = true;
%         exp.stat_sim_duration = stat_duration;
%         if strcmp(stat_attack{a}, 'NoAttack')
%             exp.start_time_FDIA = stat_duration + 1000;
%             exp.FDIA_length = 100;
%         else
%             exp.start_time_FDIA = 0;
%             exp.FDIA_length = stat_duration;
%         end
%         exp.watermark_idx = stat_wm(w);
%         if stat_wm(w) == 0
%             exp.start_time_QW = stat_duration + 1000;
%         else
%             exp.start_time_QW = 0;
%         end
%          exp.d_target = [6.35;6.20];
%         exp.ramp_len = 100;
%         exp.sign_vec = [1; 1];
%         exp.plot_residual = false;
%         exp.plot_liquid_level = false;
%         exp.plot_residual_square = false;
%         exp.plot_performance = false;
%         exp.plot_attack_energy = false;
%         exp_list{end+1} = exp;
%     end
% end
% 
% %% 实验8：计算无水印、最优弱、最优强对应的残差阈值（不画图）
% threshold_wm_idx = [0, 3, 4];   % 无水印、最优弱、最优强
% threshold_wm_names = {'No_watermark', 'Weak', 'Strong'};
% for i = 1:length(threshold_wm_idx)
%     exp.name = sprintf('08_Thresholds_%s', threshold_wm_names{i});
%     exp.calc_threshold = true;           % 标志：只计算阈值，不绘图
%     % 攻击参数（无关，设置为不影响仿真即可，可沿用实验7的设置）
%     exp.stat_sim_duration = 2000;        % 仿真时长（仅用于生成噪声）
%     exp.start_time_FDIA = exp.stat_sim_duration + 1000;   % 不攻击
%     exp.FDIA_length = 100;
%     exp.watermark_idx = threshold_wm_idx(i);
%     % 水印时间：无水印时远大于仿真时间，有水印时 = 0
%     if threshold_wm_idx(i) == 0
%         exp.start_time_QW = exp.stat_sim_duration + 1000;
%     else
%         exp.start_time_QW = 0;
%     end
%     exp.d_target = [6.35; 6.20];   % 以下参数虽用不到，但必须存在
%     exp.ramp_len = 100;
%     exp.sign_vec = [1; 1];
%     exp.plot_residual = false;
%     exp.plot_liquid_level = false;
%     exp.plot_residual_square = false;
%     exp.plot_performance = false;
%     exp.plot_attack_energy = false;
%     exp_list{end+1} = exp;
% end

%% 实验9a：最优弱水印 — 原有阈值（0.3）vs 新阈值（κ=5）检测性能对比
exp.name = '09a_Threshold_Comparison_OptimalWeak';
exp.calc_detection_compare = true;   % 特殊标志：阈值对比
exp.kappa = 5;                        % 容限系数
exp.original_epsilon = 0.3;           % 原有能量阈值（可根据论文实际值修改）
exp.watermark_idx = 3;                % 最优弱水印
exp.start_time_FDIA = 250;
exp.FDIA_length = 750;
exp.start_time_QW = 500;              % 水印嵌入时间
exp.d_target = [5.5; 5.5];            % 攻击强度（幅值绕过残差检验的配置）
exp.ramp_len = 250;
exp.sign_vec = [1; 1];
exp.attack_start = exp.start_time_FDIA;                  % 攻击开始时刻
exp.attack_end   = exp.start_time_FDIA + exp.FDIA_length; % 攻击结束时刻
exp.plot_residual = false;            % 所有绘图关闭
exp.plot_liquid_level = false;
exp.plot_residual_square = false;
exp.plot_performance = false;
exp.plot_attack_energy = false;
exp_list{end+1} = exp;

%% 实验9b：最优强水印 — 原有阈值（0.3）vs 新阈值（κ=5）检测性能对比
exp = exp;                            % 复制上一个实验的结构体
exp.name = '09b_Threshold_Comparison_OptimalStrong';
exp.watermark_idx = 4;                % 改为最优强水印
exp_list{end+1} = exp;

%% 实验9c：无水印 — 原有阈值（0.3）vs 新阈值（κ=5）检测性能对比
exp.name = '09c_Threshold_Comparison_NoWatermark';
exp.calc_detection_compare = true;   % 启用阈值对比分支
exp.kappa = 5;                        % 容限系数
exp.original_epsilon = 0.3;           % 原有阈值（与有水印实验保持一致）
exp.watermark_idx = 0;                % 无水印
exp.start_time_FDIA = 250;
exp.FDIA_length = 750;
exp.start_time_QW = 2000;             % 远大于仿真时间（analog_time=1000），确保水印不触发
exp.d_target = [5.5; 5.5];            % 攻击强度（幅值绕过残差检验的配置）
exp.ramp_len = 250;
exp.sign_vec = [1; 1];
exp.attack_start = exp.start_time_FDIA;                  % 攻击开始时刻
exp.attack_end   = exp.start_time_FDIA + exp.FDIA_length; % 攻击结束时刻
exp.plot_residual = false;
exp.plot_liquid_level = false;
exp.plot_residual_square = false;
exp.plot_performance = false;
exp.plot_attack_energy = false;
exp_list{end+1} = exp;

% ===== 运行所有实验 =====
export_root = 'Figures';
% batch_experiments.m
% （前面添加路径和定义 exp_list 的部分保持不变，调用时只需：）

for i = 1:length(exp_list)
    exp = exp_list{i};
    exp.export_root = 'Figures';
    fprintf('===== 运行实验 [%d/%d]：%s =====\n', i, length(exp_list), exp.name);
    run_experiment(exp);     % 不再传递 G, H 等参数
    close all;
end
fprintf('所有实验完成。图片保存在 %s 文件夹。\n', export_root);