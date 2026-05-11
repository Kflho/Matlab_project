clear; clc;

%% --- 1. 系统参数设置 (System Parameters) ---
T = 550;               % 攻击持续时间
p_init = 0.01;        % 初始攻击到达率猜测
gamma = 0.95;         % 折扣因子
grid_size = 0.005;    % 信念空间网格步长

% 性能损失矩阵
C_0 = [0.005431, 0.009773, 0.01441];    % 正常状态代价 [无, 低, 高]
C_A = [1.0748, 2.9642, 7.0931];% 受攻击状态代价 [无, 低, 高]

% 探测性能参数
DetRate = [0.0, 0.65, 0.98]; 

% 仿真配置
SimTime = 10000;              
TrueAtkFreq = 0.05;   %真实攻击频率       
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
rec_prob = zeros(SimTime, 1); 
rec_policy = zeros(SimTime, 1); 
rec_p_est = zeros(SimTime, 1); 

for t = 1:SimTime
    
    % --- 【原有提示逻辑】：定期触发 POMDP 策略重算 ---
    if mod(t-1, PolicyUpdateInterval) == 0
        if t > 1
            % 更新频率估计
            start_idx = max(1, t - PolicyUpdateInterval);
            curr_p = max(0.001, sum(AtkCounter(start_idx : t-1)) / PolicyUpdateInterval);
            fprintf('\n--- 重新计算周期到达 (t=%d) ---\n', t);
            fprintf('检测到过去周期的实际到达频率: %.4f\n', curr_p);
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

%% --- 5. 可视化展示 ---
figure('Color', 'w', 'Position', [100, 100, 1000, 800]);

% 子图 1: 频率估计
subplot(3,1,1); hold on;
plot(0:SimTime-1, rec_p_est, 'r', 'LineWidth', 2, 'DisplayName', '估计有效频率 \hat{p}');
% 修正后的理论上限公式
CorrectedEffP = TrueAtkFreq / (1 + TrueAtkFreq * (T + MinGap - 1));
yline(CorrectedEffP, 'k--', 'LineWidth', 1.5, 'DisplayName', '修正理论上限');
ylabel('频率参数', 'Interpreter', 'tex');
title('频率动态估计与理论值对比', 'Interpreter', 'tex');
legend('Location', 'northeast'); grid on; xlim([0, SimTime]); 
ylim([0, max(max(rec_p_est), CorrectedEffP) * 1.5]);

% 子图 2: 怀疑度
subplot(3,1,2); hold on;
diff_gt = diff([0; GroundTruth; 0]);
s_atks = find(diff_gt==1); e_atks = find(diff_gt==-1)-1;
for i=1:length(s_atks)
    patch([s_atks(i) e_atks(i) e_atks(i) s_atks(i)], [0 0 1 1], [0.9 0.9 0.9], 'EdgeColor', 'none', 'HandleVisibility', 'off');
end
plot(0:SimTime-1, rec_prob, 'b', 'LineWidth', 1.5);
ylabel('怀疑度', 'Interpreter', 'tex'); title('怀疑度演化 (Pr(s>0))', 'Interpreter', 'tex');
grid on; ylim([-0.05 1.05]); xlim([0, SimTime]);

% 子图 3: 动作
subplot(3,1,3);
stairs(0:SimTime-1, rec_policy, 'm', 'LineWidth', 1.5);
ylim([-0.2 2.2]); yticks([0 1 2]); yticklabels({'无','低强度','高强度'});
ylabel('建议动作', 'Interpreter', 'tex'); xlabel('时间 (秒)', 'Interpreter', 'tex');
grid on; xlim([0, SimTime]);