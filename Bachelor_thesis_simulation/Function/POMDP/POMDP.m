% POMDP_v10.m — 考虑误报率的动态水印触发与切换仿真
% 修正版：修复 P_step 初始化、观测索引错误、转移矩阵更新位置

addpath('D:\local_data\software_data\programming_data\Matlab_project\Common\Visualization');
clear; clc;
output_dir = 'Figures_POMDP';
if ~exist(output_dir, 'dir'), mkdir(output_dir); end

% 启动并行池
if isempty(gcp('nocreate'))
    parpool('local');
end

% 全局图形属性
set(0, 'DefaultFigureColor',        'w');
set(0, 'DefaultAxesFontName',       '宋体');
set(0, 'DefaultAxesFontSize',       9);
set(0, 'DefaultAxesLineWidth',       1.0);
set(0, 'DefaultAxesTickDir',        'in');
set(0, 'DefaultAxesTickLength',     [0.015 0.015]);
set(0, 'DefaultTextFontName',       '宋体');
set(0, 'DefaultTextFontSize',       10);
set(0, 'DefaultLegendFontName',     '宋体');
set(0, 'DefaultLegendFontSize',     8);
set(0, 'DefaultLegendBox',          'off');
set(0, 'DefaultLineLineWidth',      1.5);

%% --- 1. 系统参数 ---
T = 50;               % 攻击持续时间（可根据仿真需要调整）
p_init = 0.05;         % 初始攻击猜测频率
p_min = 0.01;
gamma = 0.95;          % 折扣因子
grid_size = 0.005;     % 信念离散化步长

% 性能损失矩阵（正常/受攻击） [无, 弱, 强]
C_0 = [3.0648, 3.0484, 3.1312];
C_A = [847.71, 46.39, 314.38];

% 检测性能参数（基于实验9新阈值数据）
DetRate = [0.4168, 0.2250, 0.0200];        % 检测率   [无水印, 弱水印, 强水印]
FalseAlarmRate = [0.1920, 0.1400, 0.0000]; % 误报率   [无水印, 弱水印, 强水印]

% 仿真配置
SimTime = 10000;
TrueAtkFreq = 0.1;           % 真实攻击频率
PolicyUpdateInterval = 5000;   % 策略重算间隔

%% --- 2. 攻击生成（物理隔离）---
GroundTruth = zeros(SimTime, 1);
AtkCounter = zeros(1, SimTime);
t_gen = 1;
MinGap = 1;
while t_gen <= SimTime - T
    if rand() < TrueAtkFreq
        AtkCounter(t_gen) = 1;
        atk_end = t_gen + T - 1;
        GroundTruth(t_gen : atk_end) = 1;
        t_gen = t_gen + T + MinGap;
    else
        t_gen = t_gen + 1;
    end
end

%% --- 3. 仿真主循环 ---
curr_p = p_init;
test_b = [1, zeros(1, T)];      % 信念向量（正常, 攻击剩余1..T）
rec_prob = zeros(SimTime, 1);
rec_policy = zeros(SimTime, 1);
rec_p_est = zeros(SimTime, 1);
period_costs = zeros(1, 4);     % 累加器：[不加水印, 弱水印, 强水印, POMDP]

% 初始化 P_step（用当前 curr_p）
P_step = zeros(T+1, T+1);
P_step(1,1) = 1-curr_p; P_step(1,2) = curr_p;
for i = 2:T, P_step(i, i+1) = 1; end
P_step(T+1, 1) = 1;

for t = 1:SimTime
    % ----- 定期重算POMDP策略 -----
    if mod(t-1, PolicyUpdateInterval) == 0
        if t > 1
            start_idx = max(1, t - PolicyUpdateInterval);
            curr_p = max(p_min, sum(AtkCounter(start_idx : t-1)) / PolicyUpdateInterval);
            avg_costs = period_costs / PolicyUpdateInterval;
            fprintf('\n==================================================\n');
            fprintf('--- 重新计算周期 (t=%d) ---\n', t);
            fprintf('估计攻击频率: %.4f\n', curr_p);
            fprintf('单步平均损失: 不加:%.6f, 弱:%.6f, 强:%.6f, POMDP:%.6f\n', ...
                    avg_costs(1), avg_costs(2), avg_costs(3), avg_costs(4));
            fprintf('周期总损失: [%.2f, %.2f, %.2f, %.2f]\n', ...
                    period_costs(1), period_costs(2), period_costs(3), period_costs(4));
            period_costs = zeros(1, 4);
        else
            fprintf('初始化 POMDP (p=%.4f)...\n', curr_p);
        end
        % --- [核心A] 信念空间枚举 ---
        B = [1, zeros(1, T)];
        P = zeros(T+1, T+1);
        P(1,1) = 1-curr_p; P(1,2) = curr_p;
        for i = 2:T, P(i, i+1) = 1; end
        P(T+1, 1) = 1;
        for level = 1:(T*5)
            old_n = size(B, 1);
            B = [B; B * P];
            B = round(B / grid_size) * grid_size;
            B = unique(round(B, 8), 'rows');
            if size(B,1)==old_n || size(B,1)>2000, break; end
        end
        n_beliefs = size(B, 1);
        fprintf('信念点个数: %d\n', n_beliefs);
        % --- 预计算转移索引 ---
        next_idx_0 = zeros(n_beliefs, 1);
        parfor i = 1:n_beliefs
            b_pred = round(B(i,:) * P / grid_size) * grid_size;
            [~, next_idx_0(i)] = min(sum(abs(B - b_pred), 2));
        end
        % 定义后验更新函数句柄
        bayes_update = @(b_pred, a, obs) bayesian_posterior(b_pred, a, obs, DetRate, FalseAlarmRate, grid_size);
        next_idx_a1_o0 = zeros(n_beliefs, 1);
        next_idx_a1_o1 = zeros(n_beliefs, 1);
        next_idx_a2_o0 = zeros(n_beliefs, 1);
        next_idx_a2_o1 = zeros(n_beliefs, 1);
        parfor i = 1:n_beliefs
            b_pred = B(i,:) * P;   % 非离散化
            % a=1
            bp10 = bayes_update(b_pred, 1, 0);
            bp11 = bayes_update(b_pred, 1, 1);
            [~, next_idx_a1_o0(i)] = min(sum(abs(B - bp10), 2));
            [~, next_idx_a1_o1(i)] = min(sum(abs(B - bp11), 2));
            % a=2
            bp20 = bayes_update(b_pred, 2, 0);
            bp21 = bayes_update(b_pred, 2, 1);
            [~, next_idx_a2_o0(i)] = min(sum(abs(B - bp20), 2));
            [~, next_idx_a2_o1(i)] = min(sum(abs(B - bp21), 2));
        end
        % --- [核心B] 值迭代 ---
        fprintf('值迭代中...\n');
        V = zeros(n_beliefs, 1);
        policy = zeros(n_beliefs, 1);
        for iter = 1:1000
            V_old = V;
            V_temp = zeros(n_beliefs, 1);
            policy_temp = zeros(n_beliefs, 1);
            parfor i_core = 1:n_beliefs
                b = B(i_core,:);
                b0 = b(1);
                imm = b0*C_0 + (1-b0)*C_A;   % 1x3 向量：[无,弱,强]
                % 动作0：不加水印
                q0 = imm(1) + gamma * V_old(next_idx_0(i_core));
                % 动作1：弱水印
                p_alarm_1 = b0*FalseAlarmRate(2) + (1-b0)*DetRate(2);
                q1 = imm(2) + gamma * ( p_alarm_1      * V_old(next_idx_a1_o1(i_core)) ...
                                     + (1-p_alarm_1) * V_old(next_idx_a1_o0(i_core)) );
                % 动作2：强水印
                p_alarm_2 = b0*FalseAlarmRate(3) + (1-b0)*DetRate(3);
                q2 = imm(3) + gamma * ( p_alarm_2      * V_old(next_idx_a2_o1(i_core)) ...
                                     + (1-p_alarm_2) * V_old(next_idx_a2_o0(i_core)) );
                [V_temp(i_core), best_a] = min([q0, q1, q2]);
                policy_temp(i_core) = best_a - 1;   % 0,1,2
            end
            V = V_temp;
            policy = policy_temp;
            if max(abs(V - V_old)) < 1e-6
                fprintf('收敛于第 %d 次迭代\n', iter);
                break;
            end
        end
    end

    % ----- 4. 实时执行与信念更新 -----
    % 找到当前信念点
    t_b_q = round(test_b / grid_size) * grid_size;
    [~, idx] = min(sum(abs(B - t_b_q), 2));
    act = policy(idx);
    rec_policy(t) = act;
    rec_prob(t) = 1 - test_b(1);
    rec_p_est(t) = curr_p;

    % 累积四种策略的损失
    if GroundTruth(t) == 1
        period_costs(1) = period_costs(1) + C_A(1);
        period_costs(2) = period_costs(2) + C_A(2);
        period_costs(3) = period_costs(3) + C_A(3);
        period_costs(4) = period_costs(4) + C_A(act+1);
    else
        period_costs(1) = period_costs(1) + C_0(1);
        period_costs(2) = period_costs(2) + C_0(2);
        period_costs(3) = period_costs(3) + C_0(3);
        period_costs(4) = period_costs(4) + C_0(act+1);
    end

    % ---------- 贝叶斯信念更新（修正后）----------
    % 1. 更新转移矩阵 P_step
    P_step = zeros(T+1, T+1);
    P_step(1,1) = 1-curr_p; P_step(1,2) = curr_p;
    for i = 2:T, P_step(i, i+1) = 1; end
    P_step(T+1, 1) = 1;

    % 2. 预测步
    b_pred = test_b * P_step;

    % 3. 生成观测（注意索引修正为 act+1）
    if act == 0
        obs = [];                  % 无观测
    else
        if GroundTruth(t) == 1
            if rand() < DetRate(act+1)
                obs = 1;
            else
                obs = 0;
            end
        else
            if rand() < FalseAlarmRate(act+1)
                obs = 1;
            else
                obs = 0;
            end
        end
    end

    % 4. 后验更新
    if act == 0
        test_b = b_pred;
    else
        test_b = bayesian_posterior(b_pred, act, obs, DetRate, FalseAlarmRate, grid_size);
    end
end

% --- 尾部统计 ---
rem_steps = mod(SimTime, PolicyUpdateInterval);
if rem_steps == 0, rem_steps = PolicyUpdateInterval; end
avg_costs = period_costs / rem_steps;
fprintf('\n=== 最终阶段损失对比 ===\n');
fprintf('不加:%.6f, 弱:%.6f, 强:%.6f, POMDP:%.6f\n', ...
        avg_costs(1), avg_costs(2), avg_costs(3), avg_costs(4));

%% --- 5. 可视化展示 + 导出 ---

% 图窗 1：频率估计
figure('Color', 'w', 'Position', [100, 100, 1000, 800]);
hold on;
plot(0:SimTime-1, rec_p_est, 'r', 'DisplayName', '估计有效频率 \hat{p}');
CorrectedEffP = TrueAtkFreq / (1 + TrueAtkFreq * (T + MinGap - 1));
yline(CorrectedEffP, 'k--', 'DisplayName', '修正理论上限');
ylabel('频率参数', 'Interpreter', 'tex');
title('频率动态估计与理论值对比', 'Interpreter', 'tex');
legend('Location', 'best');
grid on; xlim([0, SimTime]);
ylim([0, max(max(rec_p_est), CorrectedEffP) * 1.5]);
hold off;

fig_setting; axes_setting_2d; label_setting_2d; legend_setting; title_setting;
Export_fig_paper(gcf, fullfile(output_dir, 'fig_POMDP_freq_estimation'), 5.5);

% 图窗 2：怀疑度演化
figure('Color', 'w', 'Position', [100, 100, 1000, 800]);
hold on;
diff_gt = diff([0; GroundTruth; 0]);
s_atks = find(diff_gt==1); e_atks = find(diff_gt==-1)-1;
for i = 1:length(s_atks)
    patch([s_atks(i) e_atks(i) e_atks(i) s_atks(i)], [0 0 1 1], ...
        [0.9 0.9 0.9], 'EdgeColor', 'none', 'HandleVisibility', 'off');
end
plot(0:SimTime-1, rec_prob, 'b', 'DisplayName', '怀疑度');
ylabel('怀疑度', 'Interpreter', 'tex');
title('怀疑度演化 (Pr(s>0))', 'Interpreter', 'tex');
grid on; ylim([-0.05 1.05]); xlim([0, SimTime]);
hold off;

fig_setting; axes_setting_2d; label_setting_2d; title_setting;
Export_fig_paper(gcf, fullfile(output_dir, 'fig_POMDP_suspicion'), 5.5);

% 图窗 3：水印动作策略
figure('Color', 'w', 'Position', [100, 100, 1000, 800]);
hold on;
stairs(0:SimTime-1, rec_policy, 'm', 'DisplayName', '建议动作');
ylim([-0.2 2.2]); yticks([0 1 2]); yticklabels({'无','低强度','高强度'});
ylabel('建议动作', 'Interpreter', 'tex');
xlabel('时间 (秒)', 'Interpreter', 'tex');
title('水印触发与切换策略', 'Interpreter', 'tex');
grid on; xlim([0, SimTime]);
hold off;

fig_setting; axes_setting_2d; label_setting_2d; title_setting;
Export_fig_paper(gcf, fullfile(output_dir, 'fig_POMDP_policy'), 5.5);

fprintf('图片已导出至文件夹：%s\n', output_dir);

% --- 辅助函数（贝叶斯后验） ---
function b_post = bayesian_posterior(b_pred, a, obs, DetRate, FalseAlarmRate, grid_size)
    % 贝叶斯后验信念计算
    % b_pred: 1×(T+1) 预测信念
    % a: 动作 (1=弱，2=强)
    % obs: 观测 (0或1)
    T_len = length(b_pred) - 1;
    if a == 1
        idx = 2;
    elseif a == 2
        idx = 3;
    else
        error('a must be 1 or 2');
    end
    % 似然函数
    if obs == 1
        L = [FalseAlarmRate(idx), DetRate(idx)*ones(1, T_len)];
    else
        L = [1-FalseAlarmRate(idx), (1-DetRate(idx))*ones(1, T_len)];
    end
    b_post = b_pred .* L;
    b_post = round(b_post / grid_size) * grid_size;
    s = sum(b_post);
    if s > 0
        b_post = b_post / s;
    else
        b_post = b_pred;   % 防止零和
    end
end