clear; clc;

%% --- 1. 系统参数设置 (System Parameters) ---
T = 550;               % 攻击持续时间
p_init = 0.05;        % 初始攻击到达率猜测
p_min=0.01;
gamma = 0.95;         % 折扣因子
grid_size = 0.005;    % 信念空间网格步长

% 性能损失矩阵
C_0 = [0.003168, 0.0008343, 0.004948];      % 正常状态代价 [无, 低, 高]
C_A = [0.9247, 2.5481, 6.5577];             % 受攻击状态代价 [无, 低, 高]

% 探测性能参数
DetRate = [0.0, 0.65, 0.98]; 

% 仿真配置
SimTime = 10000;              
TrueAtkFreq = 0.001;   %真实攻击频率       
PolicyUpdateInterval = 5000; % 策略重演算周期

%% --- 2. 攻击生成逻辑 (严格物理隔离) ---
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
test_b = [1, zeros(1, T)]; 

% 保留原有绘图记录数组
rec_prob = zeros(SimTime, 1); 
rec_policy = zeros(SimTime, 1); 
rec_p_est = zeros(SimTime, 1); 

% 【修改】：使用数组分别记录4种策略的周期性能损失
% 索引: 1=一直不加, 2=一直弱水印, 3=一直强水印, 4=POMDP动态切换
period_costs = zeros(1, 4); 

for t = 1:SimTime
    
    % --- 定期触发 POMDP 策略重算 ---
    if mod(t-1, PolicyUpdateInterval) == 0
        if t > 1
            % 更新频率估计
            start_idx = max(1, t - PolicyUpdateInterval);
            curr_p = max(p_min, sum(AtkCounter(start_idx : t-1)) / PolicyUpdateInterval);
            
            % 计算平均期望
            avg_costs = period_costs / PolicyUpdateInterval;
            
            % 【新增】：对比输出四种方案的性能损失期望
            fprintf('\n==================================================\n');
            fprintf('--- 重新计算周期到达 (t=%d) ---\n', t);
            fprintf('检测到过去周期的实际到达频率: %.4f\n', curr_p);
            fprintf('\n▶ 单步性能损失期望 (平均开销) 对比:\n');
            fprintf('  1. 一直不加水印 : %.6f\n', avg_costs(1));
            fprintf('  2. 一直加弱水印 : %.6f\n', avg_costs(2));
            fprintf('  3. 一直加强水印 : %.6f\n', avg_costs(3));
            fprintf('  4. POMDP动态切换: %.6f\n', avg_costs(4));
            
            fprintf('\n▶ 周期总性能开销 对比:\n');
            fprintf('  [不加: %.2f, 弱: %.2f, 强: %.2f, 动态: %.2f]\n', ...
                period_costs(1), period_costs(2), period_costs(3), period_costs(4));
            fprintf('==================================================\n\n');
            
            % 清零累加器，准备下一个周期
            period_costs = zeros(1, 4);
        else
            fprintf('正在初始化 POMDP 模型 (初始 p=%.4f)...\n', curr_p);
        end
        
        fprintf('正在枚举信念空间与预计算转移索引...\n');
        
        % [核心逻辑 A：信念集计算]
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
            if size(B, 1) == old_n || size(B, 1) > 2000, break; end
        end
        
        n_beliefs = size(B, 1); 
        next_idx_unobs = zeros(n_beliefs, 1);
        for i = 1:n_beliefs
            b_n0 = round(B(i,:) * P / grid_size) * grid_size;
            [~, next_idx_unobs(i)] = min(sum(abs(B - b_n0), 2));
        end
        fprintf('信念空间计算完成，共有 %d 个离散信念点。\n', n_beliefs);
        
        % [核心逻辑 B：值迭代求解]
        fprintf('正在进行值迭代求解最优策略...\n');
        V = zeros(n_beliefs, 1);      
        policy = zeros(n_beliefs, 1); 
        for iter = 1:1000
            V_old = V;
            for i = 1:n_beliefs
                b = B(i, :);
                imm = b(1)*C_0 + (1-b(1))*C_A; 
                q0 = imm(1) + gamma * V_old(next_idx_unobs(i));
                q_rest = imm(2:3) + gamma * V_old(1); 
                [V(i), best_a] = min([q0, q_rest]); 
                policy(i) = best_a - 1; 
            end
            if max(abs(V - V_old)) < 1e-6
                fprintf('值迭代于第 %d 次迭代收敛。\n', iter);
                break; 
            end 
        end
    end

    % --- 4. 实时更新逻辑 ---
    t_b_q = round(test_b / grid_size) * grid_size;
    [~, idx] = min(sum(abs(B - t_b_q), 2));
    act = policy(idx); 
    
    rec_policy(t) = act;
    rec_prob(t) = 1 - test_b(1); 
    rec_p_est(t) = curr_p;
    
    % 【新增】：对比计算4种情况下的真实开销并累加
    if GroundTruth(t) == 1
        period_costs(1) = period_costs(1) + C_A(1);      % 一直不加
        period_costs(2) = period_costs(2) + C_A(2);      % 一直弱水印
        period_costs(3) = period_costs(3) + C_A(3);      % 一直强水印
        period_costs(4) = period_costs(4) + C_A(act+1);  % POMDP
    else
        period_costs(1) = period_costs(1) + C_0(1);      % 一直不加
        period_costs(2) = period_costs(2) + C_0(2);      % 一直弱水印
        period_costs(3) = period_costs(3) + C_0(3);      % 一直强水印
        period_costs(4) = period_costs(4) + C_0(act+1);  % POMDP
    end
    
    P_step = zeros(T+1, T+1);
    P_step(1,1) = 1-curr_p; P_step(1,2) = curr_p;
    for i = 2:T, P_step(i, i+1) = 1; end
    P_step(T+1, 1) = 1;

    if act > 0
        if GroundTruth(t) == 1 && rand() < DetRate(act+1)
            b_new = test_b * P_step;
            b_new(1) = 0; test_b = b_new / sum(b_new); 
        else
            b_pred = test_b * P_step;
            dr = DetRate(act+1); 
            test_b(1) = b_pred(1); 
            test_b(2:end) = b_pred(2:end) * (1 - dr); 
            test_b = test_b / sum(test_b); 
        end
    else
        test_b = test_b * P_step;
    end
end

% 【新增】：仿真结束时的尾部数据输出
rem_steps = mod(SimTime, PolicyUpdateInterval);
if rem_steps == 0
    rem_steps = PolicyUpdateInterval;
end
avg_costs = period_costs / rem_steps;

fprintf('\n==================================================\n');
fprintf('=== 仿真结束收尾数据 (t=%d) ===\n', SimTime);
fprintf('\n▶ 最终阶段单步性能损失期望 (平均开销) 对比:\n');
fprintf('  1. 一直不加水印 : %.6f\n', avg_costs(1));
fprintf('  2. 一直加弱水印 : %.6f\n', avg_costs(2));
fprintf('  3. 一直加强水印 : %.6f\n', avg_costs(3));
fprintf('  4. POMDP动态切换: %.6f\n', avg_costs(4));
fprintf('==================================================\n\n');


%% --- 5. 可视化展示 (完全保留原版) ---
figure('Color', 'w', 'Position', [100, 100, 1000, 800]);

% 子图 1: 频率估计
plot(1); hold on;
plot(0:SimTime-1, rec_p_est, 'r', 'LineWidth', 2, 'DisplayName', '估计有效频率 \hat{p}');
% 修正后的理论上限公式
CorrectedEffP = TrueAtkFreq / (1 + TrueAtkFreq * (T + MinGap - 1));
yline(CorrectedEffP, 'k--', 'LineWidth', 1.5, 'DisplayName', '修正理论上限');
ylabel('频率参数', 'Interpreter', 'tex');
title('频率动态估计与理论值对比', 'Interpreter', 'tex');
legend('Location', 'northeast'); grid on; xlim([0, SimTime]); 
ylim([0, max(max(rec_p_est), CorrectedEffP) * 1.5]);

% 子图 2: 怀疑度
figure('Color', 'w', 'Position', [100, 100, 1000, 800]);
plot(2); hold on;
diff_gt = diff([0; GroundTruth; 0]);
s_atks = find(diff_gt==1); e_atks = find(diff_gt==-1)-1;
for i=1:length(s_atks)
    patch([s_atks(i) e_atks(i) e_atks(i) s_atks(i)], [0 0 1 1], [0.9 0.9 0.9], 'EdgeColor', 'none', 'HandleVisibility', 'off');
end
plot(0:SimTime-1, rec_prob, 'b', 'LineWidth', 1.5);
ylabel('怀疑度', 'Interpreter', 'tex'); title('怀疑度演化 (Pr(s>0))', 'Interpreter', 'tex');
grid on; ylim([-0.05 1.05]); xlim([0, SimTime]);

% 子图 3: 动作
figure('Color', 'w', 'Position', [100, 100, 1000, 800]);
plot(3);hold on
stairs(0:SimTime-1, rec_policy, 'm', 'LineWidth', 1.5);
ylim([-0.2 2.2]); yticks([0 1 2]); yticklabels({'无','低强度','高强度'});
ylabel('建议动作', 'Interpreter', 'tex'); xlabel('时间 (秒)', 'Interpreter', 'tex');
grid on; xlim([0, SimTime]);