clear; clc;

%% --- 1. 系统参数设置 ---
T = 100;             
p = 0.01;           
gamma = 0.95;       
grid_size = 0.005;  

% 使用搜索脚本找到的典型参数组合（这组参数通常能出三级跳）
C_0 = [5, 45, 100];    
C_A = [1000, 800, 10]; 

%% --- 2. 网格化信念空间枚举 ---
fprintf('正在计算信念空间 (T=%d)...\n', T);
B = [1, zeros(1, T)]; 
P = zeros(T+1, T+1);
P(1,1) = 1-p; P(1,2) = p;
for i = 2:T, P(i, i+1) = 1; end
P(T+1, 1) = 1; 

for level = 1:(T*5)
    old_n = size(B, 1);
    % 简化路径：不加水印 vs 加水印复位
    B_next_unobs = B * P;
    % 汇总并网格化
    B = [B; B_next_unobs];
    B = round(B / grid_size) * grid_size; 
    B = max(0, min(1, B)); B = B ./ sum(B, 2);    
    B = unique(round(B, 8), 'rows'); 
    if size(B, 1) == old_n || size(B, 1) > 3000, break; end
end
n_beliefs = size(B, 1);

%% --- 3. 预计算转移索引 (保持逻辑高度一致) ---
fprintf('预计算转移表...\n');
next_idx_unobs = zeros(n_beliefs, 1);
for i = 1:n_beliefs
    b_n0 = round(B(i,:) * P / grid_size) * grid_size;
    b_n0 = b_n0 / sum(b_n0);
    [~, next_idx_unobs(i)] = min(sum(abs(B - b_n0), 2));
end

%% --- 4. 值迭代 (核心计算：检测即复位) ---
fprintf('值迭代求解策略...\n');
V = zeros(n_beliefs, 1); policy = zeros(n_beliefs, 1);
for iter = 1:1000
    V_old = V;
    for i = 1:n_beliefs
        b = B(i, :);
        % 即时代价：Pr(s=0)*C0 + Pr(s>0)*CA
        imm = b(1)*C_0 + (1-b(1))*C_A; 
        
        % 动作0：不检测，信念继续按转移矩阵 P 演化
        q0 = imm(1) + gamma * V_old(next_idx_unobs(i));
        
        % 动作1,2：检测即复位。无论有无攻击，下一秒都回到确信无攻击状态 B(1,:)
        % 这是你要求的事实逻辑：检测能发现并清除风险
        q_rest = imm(2:3) + gamma * V_old(1); 
        
        [V(i), best_a] = min([q0, q_rest]);
        policy(i) = best_a - 1;
    end
    if max(abs(V - V_old)) < 1e-6, break; end
end

% --- 检查：策略表中是否真的包含三种动作？ ---
found_actions = unique(policy);
fprintf('策略表中包含的动作有: %s\n', mat2str(found_actions));

%% --- 5. 仿真与可视化 ---
% 如果上面显示包含 [0 1 2]，但图中没有动作2，说明动作1复位太快了。
% 我们在图中画出“如果我不复位，策略会怎么变”，来验证策略的完整性。

sim_time = T * 2; 
test_b = [1, zeros(1, T)]; 
rec_prob = zeros(sim_time, 1); 
rec_policy_real = zeros(sim_time, 1); % 真实复位情况
rec_policy_theoretical = zeros(sim_time, 1); % 不复位情况（看策略全貌）

b_theoretical = [1, zeros(1, T)];

for t = 1:sim_time
    % 1. 真实轨迹 (检测即复位)
    t_b_q = round(test_b / grid_size) * grid_size;
    [~, idx] = min(sum(abs(B - t_b_q), 2));
    rec_policy_real(t) = policy(idx);
    rec_prob(t) = 1 - test_b(1);
    if rec_policy_real(t) > 0, test_b = [1, zeros(1, T)]; else test_b = test_b * P; end
    
    % 2. 理论轨迹 (不复位，观察怀疑度一直上涨会发生什么)
    t_b_th = round(b_theoretical / grid_size) * grid_size;
    [~, idx_th] = min(sum(abs(B - t_b_th), 2));
    rec_policy_theoretical(t) = policy(idx_th);
    b_theoretical = b_theoretical * P;
end

% --- 绘图 ---
figure('Color', 'w', 'Position', [100, 100, 1000, 600]);

subplot(2,1,1);
plot(0:sim_time-1, rec_prob, 'b', 'LineWidth', 1.5); hold on;
title('实时怀疑度与策略响应'); ylabel('怀疑度 Pr(s>0)'); grid on;

subplot(2,1,2);
stairs(0:sim_time-1, rec_policy_real, 'r', 'LineWidth', 2, 'DisplayName', '实际执行(检测复位)'); 
hold on;
stairs(0:sim_time-1, rec_policy_theoretical, 'k--', 'LineWidth', 1, 'DisplayName', '策略全貌(若不复位)');
ylim([-0.2 2.2]); yticks([0 1 2]); yticklabels({'无','低强度','高强度'});
legend; xlabel('时间(秒)'); ylabel('动作'); grid on;