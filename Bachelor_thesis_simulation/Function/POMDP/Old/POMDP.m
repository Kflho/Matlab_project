clear; clc;

%% --- 1. 系统参数设置 ---
T = 100;             % 攻击持续时间 (秒)
p = 0.01;           % 攻击到达率 (每秒概率)
gamma = 0.95;       % 折扣因子
grid_size = 0.005;  % 概率网格步长 (防止信念爆炸的关键)

% 代价向量: [a=0(无水印), a=1(低强度), a=2(高强度)]
C_0 = [5, 50, 100];  % 正常状态下的代价
C_A = [1000, 800, 20]; % 攻击状态下的代价

%% --- 2. 网格化信念空间枚举 ---
fprintf('正在利用网格化技术压缩信念空间...\n');
B = [1, zeros(1, T)]; 

P = zeros(T+1, T+1);
P(1,1) = 1-p; P(1,2) = p;
for i = 2:T, P(i, i+1) = 1; end
P(T+1, 1) = 1; 

for level = 1:(T*5)
    old_n = size(B, 1);
    
    % 路径演化
    B_next_unobs = B * P;
    B_next_atk = B * P; B_next_atk(:, 1) = 0; 
    row_sums = sum(B_next_atk, 2);
    valid_rows = row_sums > 1e-6;
    B_next_atk(valid_rows, :) = B_next_atk(valid_rows, :) ./ row_sums(valid_rows);
    
    % 关键：网格化合并逻辑
    B = [B; B_next_unobs; B_next_atk(valid_rows, :)];
    B = round(B / grid_size) * grid_size; 
    B = max(0, min(1, B)); 
    B = B ./ sum(B, 2);    
    B = unique(round(B, 8), 'rows'); 
    
    if mod(level, 20) == 0, fprintf('层级 %d | 状态点: %d\n', level, size(B, 1)); end
    if size(B, 1) == old_n || size(B, 1) > 3000, break; end
end
n_beliefs = size(B, 1);

%% --- 3. 预计算转移索引 ---
fprintf('正在预计算转移表...\n');
next_idx_unobs = zeros(n_beliefs, 1);
next_idx_atk = zeros(n_beliefs, 1);
p_atk_vec = zeros(n_beliefs, 1);

for i = 1:n_beliefs
    b = B(i, :);
    b_n0 = round(b * P / grid_size) * grid_size; b_n0 = b_n0 / sum(b_n0);
    [~, next_idx_unobs(i)] = min(sum(abs(B - b_n0), 2));
    
    p_atk_vec(i) = 1 - (b(1)*(1-p) + b(T+1));
    if p_atk_vec(i) > 1e-6
        b_na = b * P; b_na(1) = 0;
        b_na = round(b_na / sum(b_na) / grid_size) * grid_size; b_na = b_na / sum(b_na);
        [~, next_idx_atk(i)] = min(sum(abs(B - b_na), 2));
    else
        next_idx_atk(i) = 1; 
    end
end

%% --- 4. 值迭代 ---
fprintf('开始值迭代求解...\n');
V = zeros(n_beliefs, 1);
policy = zeros(n_beliefs, 1);
for iter = 1:500
    V_old = V;
    for i = 1:n_beliefs
        b = B(i, :);
        imm_costs = b(1)*C_0 + sum(b(2:end))*C_A;
        q0 = imm_costs(1) + gamma * V_old(next_idx_unobs(i));
        p_atk = p_atk_vec(i);
        q_rest = imm_costs(2:3) + gamma * ((1-p_atk)*V_old(1) + p_atk*V_old(next_idx_atk(i)));
        [V(i), best_a] = min([q0, q_rest]);
        policy(i) = best_a - 1;
    end
    if max(abs(V - V_old)) < 1e-5, break; end
end

%% --- 5. 每秒最优策略建议可视化 ---
fprintf('\n正在生成决策仿真轨迹图...\n');
sim_time = T + 20; 
test_b = [1, zeros(1, T)]; 
rec_prob = zeros(sim_time, 1); 
rec_policy = zeros(sim_time, 1); 

for t = 1:sim_time
    % 当前信念映射
    t_b_q = round(test_b / grid_size) * grid_size; t_b_q = t_b_q / sum(t_b_q);
    [~, idx] = min(sum(abs(B - t_b_q), 2));
    
    rec_policy(t) = policy(idx);
    rec_prob(t) = 1 - test_b(1);
    
    % 系统自然演化：假设在策略建议开启水印时，检测结果均为“无攻击”
    if rec_policy(t) > 0
        test_b = [1, zeros(1, T)]; % 观测到正常，风险复位
    else
        test_b = test_b * P; % 风险继续累积
    end
end

% --- 绘图 ---
figure('Color', 'w', 'Position', [100, 100, 900, 500]);
subplot(2,1,1);
plot(0:sim_time-1, rec_prob, 'LineWidth', 2, 'Color', [0 0.45 0.74]);
ylabel('受攻击怀疑度 (Pr>0)');
title(['POMDP 最优策略动态响应轨迹 (T=', num2str(T), ')']);
grid on; hold on;

subplot(2,1,2);
stairs(0:sim_time-1, rec_policy, 'LineWidth', 2, 'Color', [0.85 0.33 0.1]);
ylim([-0.2 2.2]); yticks([0 1 2]);
yticklabels({'无水印', '低强度检测', '高强度防御'});
xlabel('时间 (秒)'); ylabel('建议动作');
grid on;

% 标注触发检测的点
hold on;
for t = 1:sim_time
    if rec_policy(t) > 0
        subplot(2,1,1);
        plot(t-1, rec_prob(t), 'ro', 'MarkerSize', 8);
    end
end

fprintf('仿真完成。图表展示了系统在正常运行时，如何根据风险累积自动安排“最佳检测时机”。\n');