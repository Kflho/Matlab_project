clear; clc;

%% --- 1. 系统参数设置 ---
T = 100;             
p = 0.01;           
gamma = 0.95;       
grid_size = 0.005;  

% 建议参数（确保策略包含 0, 1, 2）
C_0 = [5, 30, 70];
C_A = [1200, 500, 50];


% --- 攻击自定义配置区 ---
AtkStart = 60;       
AtkDuration = 30;    
% -----------------------

%% --- 2. 信念空间枚举与预计算 ---
fprintf('正在计算 POMDP 模型...\n');
B = [1, zeros(1, T)]; 
P = zeros(T+1, T+1);
P(1,1) = 1-p; P(1,2) = p;
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

%% --- 3. 值迭代求解策略 ---
V = zeros(n_beliefs, 1); policy = zeros(n_beliefs, 1);
for iter = 1:1000
    V_old = V;
    for i = 1:n_beliefs
        b = B(i, :);
        imm = b(1)*C_0 + (1-b(1))*C_A; 
        q0 = imm(1) + gamma * V_old(next_idx_unobs(i));
        % 逻辑：检测后，若无攻击回到 V(1)，若有攻击则风险清除同样回到 V(1)
        q_rest = imm(2:3) + gamma * V_old(1); 
        [V(i), best_a] = min([q0, q_rest]);
        policy(i) = best_a - 1;
    end
    if max(abs(V - V_old)) < 1e-6, break; end
end

%% --- 4. 真实攻击仿真驱动 (修正观测逻辑) ---
sim_time = T * 2; 
GroundTruth = zeros(sim_time, 1);
GroundTruth(AtkStart : min(AtkStart + AtkDuration - 1, sim_time)) = 1;

test_b = [1, zeros(1, T)]; 
rec_prob = zeros(sim_time, 1); 
rec_policy = zeros(sim_time, 1);
rec_cost = zeros(sim_time, 1);

for t = 1:sim_time
    % 1. 选择动作
    t_b_q = round(test_b / grid_size) * grid_size;
    [~, idx] = min(sum(abs(B - t_b_q), 2));
    act = policy(idx);
    rec_policy(t) = act;
    rec_prob(t) = 1 - test_b(1);
    
    % 2. 计算即时代价
    if GroundTruth(t) == 0
        rec_cost(t) = C_0(act + 1);
    else
        rec_cost(t) = C_A(act + 1);
    end
    
    % 3. 【核心修正】：观测更新逻辑
    if act > 0
        if GroundTruth(t) == 1
            % --- 发现攻击：怀疑度变为 1 ---
            % 将 s=0 的概率置 0，其余部分根据转移预测归一化
            b_pred = test_b * P;
            b_new = b_pred;
            b_new(1) = 0; % 确定不是正常状态
            if sum(b_new) > 0
                test_b = b_new / sum(b_new); 
            else
                % 极端情况：如果预测中没攻击但实际有，重置为均匀攻击分布
                test_b = [0, ones(1, T)/T];
            end
        else
            % --- 确认正常：怀疑度变为 0 ---
            test_b = [1, zeros(1, T)]; 
        end
    else
        % --- 未开启水印：盲目推演 ---
        test_b = test_b * P;
    end
end

%% --- 5. 可视化展示 ---
figure('Color', 'w', 'Position', [100, 100, 1000, 600]);

subplot(2,1,1);
% 绘制背景阴影表示真实攻击持续时间
patch([find(GroundTruth,1) find(GroundTruth,1, 'last') find(GroundTruth,1, 'last') find(GroundTruth,1)], ...
      [0 0 1 1], [0.9 0.9 0.9], 'EdgeColor', 'none', 'DisplayName', '实际攻击期');
hold on;
plot(0:sim_time-1, rec_prob, 'b', 'LineWidth', 2, 'DisplayName', '系统怀疑度 Pr(s>0)');
ylabel('怀疑度'); title('水印切换策略');
legend('Location', 'northeast'); grid on; ylim([-0.05 1.05]);

subplot(2,1,2);
stairs(0:sim_time-1, rec_policy, 'r', 'LineWidth', 2);
ylim([-0.2 2.2]); yticks([0 1 2]); yticklabels({'无','低强度','高强度'});
ylabel('建议动作'); xlabel('时间 (秒)'); grid on;