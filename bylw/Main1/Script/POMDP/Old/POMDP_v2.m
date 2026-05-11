clear; clc;

%% --- 1. 系统参数设置 ---
T = 100;             % 攻击持续时间 (秒)
p = 0.005;            % 攻击到达率 (调高到达率，让风险累积更快，逼出高强度)
gamma = 0.95;        % 折扣因子
grid_size = 0.01;   % 网格精度

% --- 代价向量调整 (关键！) ---
% 目标：让 0 -> 1 -> 2 的触发点分布在不同的怀疑度区间
C_0 = [5, 10, 30];     % 正常状态代价：动作越强，成本越高 (5 < 50 < 80)
C_A = [1000, 200, 10]; % 攻击状态代价：动作 1 防御力极弱(900)，动作 2 防御力极强(10)
% 这样设置后，系统会计算：虽然动作 2 贵，但动作 1 压根挡不住 1000 的损失。

%% --- 2. 网格化信念空间枚举 ---
fprintf('正在利用网格化技术压缩信念空间 (T=%d)...\n', T);
B = [1, zeros(1, T)]; 
P = zeros(T+1, T+1);
P(1,1) = 1-p; P(1,2) = p;
for i = 2:T, P(i, i+1) = 1; end
P(T+1, 1) = 1; 

for level = 1:(T*5)
    old_n = size(B, 1);
    B_next_unobs = B * P;
    B_next_atk = B * P; B_next_atk(:, 1) = 0; 
    row_sums = sum(B_next_atk, 2);
    valid_rows = row_sums > 1e-6;
    B_next_atk(valid_rows, :) = B_next_atk(valid_rows, :) ./ row_sums(valid_rows);
    
    B = [B; B_next_unobs; B_next_atk(valid_rows, :)];
    B = round(B / grid_size) * grid_size; 
    B = max(0, min(1, B)); B = B ./ sum(B, 2);    
    B = unique(round(B, 8), 'rows'); 
    
    if mod(level, 50) == 0, fprintf('层级 %d | 状态点: %d\n', level, size(B, 1)); end
    if size(B, 1) == old_n || size(B, 1) > 4000, break; end
end
n_beliefs = size(B, 1);

%% --- 3. 预计算转移索引 ---
fprintf('正在预计算转移表...\n');
next_idx_unobs = zeros(n_beliefs, 1);
p_atk_vec = zeros(n_beliefs, 1);

for i = 1:n_beliefs
    b = B(i, :);
    b_n0 = round(b * P / grid_size) * grid_size; b_n0 = b_n0 / sum(b_n0);
    [~, next_idx_unobs(i)] = min(sum(abs(B - b_n0), 2));
    p_atk_vec(i) = 1 - (b(1)*(1-p) + b(T+1));
end

%% --- 4. 值迭代 ---
fprintf('开始值迭代求解...\n');
V = zeros(n_beliefs, 1); policy = zeros(n_beliefs, 1);
for iter = 1:500
    V_old = V;
    for i = 1:n_beliefs
        b = B(i, :);
        imm_costs = b(1)*C_0 + sum(b(2:end))*C_A;
        q0 = imm_costs(1) + gamma * V_old(next_idx_unobs(i));
        p_atk = p_atk_vec(i);
        % 符合事实：只要开启水印(a>0)，发现没攻击(1-p_atk)则回到 B(1)，发现有攻击则按概率分布演化
        % 这里为了简化计算并符合逻辑，只要没检测到攻击，未来代价就是 V(初始点)
        q_rest = imm_costs(2:3) + gamma * ((1-p_atk)*V_old(1) + p_atk*V_old(1)); 
        % 注意：上述 (1-p_atk)*V(1) + p_atk*V(1) 实际上简化为 V(1)
        % 因为检测后系统会立刻根据结果重置或修复，回到安全起点。
        
        [V(i), best_a] = min([q0, q_rest]);
        policy(i) = best_a - 1;
    end
    if max(abs(V - V_old)) < 1e-5, break; end
end

%% --- 5. 符合事实逻辑的可视化 (检测即复位) ---
fprintf('\n正在生成决策仿真轨迹图...\n');
sim_time = T + 50; 
test_b = [1, zeros(1, T)]; 
rec_prob = zeros(sim_time, 1); 
rec_policy = zeros(sim_time, 1); 

for t = 1:sim_time
    t_b_q = round(test_b / grid_size) * grid_size; t_b_q = t_b_q / sum(t_b_q);
    [~, idx] = min(sum(abs(B - t_b_q), 2));
    
    rec_policy(t) = policy(idx);
    rec_prob(t) = 1 - test_b(1);
    
    % 符合事实：只要采取了检测动作(1或2)，怀疑度立刻归零
    if rec_policy(t) > 0
        test_b = [1, zeros(1, T)]; 
    else
        test_b = test_b * P; 
    end
end

% --- 绘图 ---
figure('Color', 'w', 'Position', [100, 100, 900, 500]);
subplot(2,1,1);
plot(0:sim_time-1, rec_prob, 'LineWidth', 2, 'Color', [0 0.45 0.74]);
ylabel('受攻击怀疑度 (Pr>0)');
title('符合物理事实的策略响应：检测即复位'); grid on;

subplot(2,1,2);
stairs(0:sim_time-1, rec_policy, 'LineWidth', 2, 'Color', [0.85 0.33 0.1]);
ylim([-0.2 2.2]); yticks([0 1 2]);
yticklabels({'无水印', '低强度', '高强度'});
xlabel('时间 (秒)'); ylabel('建议动作'); grid on;