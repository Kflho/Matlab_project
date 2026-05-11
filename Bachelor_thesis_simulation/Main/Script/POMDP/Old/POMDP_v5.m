clear; clc;

%% --- 1. 系统参数设置 (System Parameters) ---
T = 10;               % 攻击持续时间：一旦攻击发生，固定持续 30 步
p_init = 0.01;        % 初始攻击到达率猜测值：用于仿真开始时的初始策略演算
gamma = 0.95;         % 折扣因子：用于 Bellman 方程，衡量未来长期代价的权重
grid_size = 0.005;    % 信念空间离散化步长：网格划分精细度，影响计算精度与速度

% 性能损失矩阵 (Cost Matrix)
C_0 = [5, 30, 70];    % 正常状态(s=0)下的代价：[不加水印, 低强度水印, 高强度水印]
C_A = [1200, 500, 50];% 受攻击状态(s>0)下的代价：[不加水印, 低强度水印, 高强度水印]

% 探测性能参数 (Detection Parameters)
DetRate = [0.0, 0.85, 0.98]; % 不同动作下的探测成功率：[动作0, 动作1, 动作2]

% 仿真时间与更新频率配置
SimTime = 1000;              % 总仿真时间 (秒)
TrueAtkFreq = 0.001;          % 物理环境真实的攻击发起频率 (Lambda)
PolicyUpdateInterval = 500; % [可调参数] 策略重演算周期：每隔多少秒根据实测频率更新 POMDP 模型

%% --- 2. 彻底修正的攻击生成逻辑 (严格物理隔离防止黏连) ---
GroundTruth = zeros(SimTime, 1); % 真实状态序列：0 为正常，1 为受攻击（上帝视角）
AtkCounter = zeros(1, SimTime);  % 攻击发起点记录器：仅在攻击开始瞬间记为 1，用于频率统计
t = 1;                           % 时间指针
MinGap = 1;                      % 强制最小间隔：确保两次攻击之间在离散时间轴上至少有 1 秒空隙

while t <= SimTime - T
    % 在非攻击期，按物理频率 TrueAtkFreq 判定是否发动新攻击
    if rand() < TrueAtkFreq
        % 1. 记录攻击发起点
        AtkCounter(t) = 1; 
        
        % 2. 填充攻击覆盖期 (Ground Truth)
        atk_end = t + T - 1;
        GroundTruth(t : atk_end) = 1;
        
        % 3. 关键跳步：跳过整个攻击持续时间 T，并加上强制隔离间隙 MinGap
        t = t + T + MinGap; 
    else
        % 未触发攻击，步进 1 秒
        t = t + 1;
    end
end

%% --- 3. 仿真主循环 (Simulation Main Loop) ---
curr_p = p_init; % 当前模型采用的转移概率参数
test_b = [1, zeros(1, T)]; % 实时信念向量：b(1) 为正常概率，b(2:T+1) 为处于攻击第 i 步的概率
rec_prob = zeros(SimTime, 1);   % 记录序列：系统每秒对“受攻击”的怀疑度 (1 - b(1))
rec_policy = zeros(SimTime, 1); % 记录序列：系统采取的最优动作索引
rec_p_est = zeros(SimTime, 1);  % 记录序列：记录每个周期估计出的 p 值

for t = 1:SimTime
    
    % --- 每隔 PolicyUpdateInterval 秒重新计算策略 (POMDP Solver) ---
    if mod(t-1, PolicyUpdateInterval) == 0
        if t > 1
            % 在线估计：计算上一个统计周期内攻击发生的平均有效频率
            start_idx = max(1, t - PolicyUpdateInterval);
            curr_p = max(0.001, sum(AtkCounter(start_idx : t-1)) / PolicyUpdateInterval);
        end
        rec_p_est(t:min(t+PolicyUpdateInterval-1, SimTime)) = curr_p;
        
        % A. 构建状态转移矩阵 P (根据最新估计的 curr_p)
        B = [1, zeros(1, T)]; % 初始化信念集 B
        P = zeros(T+1, T+1);  
        P(1,1) = 1-curr_p; P(1,2) = curr_p; % s=0 状态转移：保持正常或开始新攻击
        for i = 2:T, P(i, i+1) = 1; end     % 攻击期内转移：剩余持续时间自动递减
        P(T+1, 1) = 1;                      % 攻击结束：返回正常状态 s=0
        
        % B. 信念空间枚举 (Belief Space Enumeration)
        for level = 1:(T*5)
            old_n = size(B, 1);
            B = [B; B * P]; % 记录所有可达的信念点
            B = round(B / grid_size) * grid_size; % 离散化网格处理
            B = unique(round(B, 8), 'rows');      % 去重
            if size(B, 1) == old_n || size(B, 1) > 2000, break; end
        end
        
        % C. 预计算无观测情况下的信念跳转索引
        n_beliefs = size(B, 1); 
        next_idx_unobs = zeros(n_beliefs, 1);
        for i = 1:n_beliefs
            b_n0 = round(B(i,:) * P / grid_size) * grid_size;
            [~, next_idx_unobs(i)] = min(sum(abs(B - b_n0), 2));
        end
        
        % D. 值迭代求解 (Value Iteration)
        V = zeros(n_beliefs, 1); policy = zeros(n_beliefs, 1);
        for iter = 1:1000
            V_old = V;
            for i = 1:n_beliefs
                b = B(i, :);
                imm = b(1)*C_0 + (1-b(1))*C_A; % 计算当前信念下的期望即时代价
                
                % 动作 0 (不检测) 的 Q 值：即时代价 + 折扣后的下一信念点代价值
                q0 = imm(1) + gamma * V_old(next_idx_unobs(i));
                % 动作 1 & 2 (检测) 的 Q 值：即时代价 + 探测后信念重置为正常态 V(1) 的期望
                q_rest = imm(2:3) + gamma * V_old(1); 
                
                [V(i), best_a] = min([q0, q_rest]); % 寻找最小化长期代价的动作
                policy(i) = best_a - 1; 
            end
            if max(abs(V - V_old)) < 1e-6, break; end 
        end
    end

    % --- 4. 实时执行与信念更新 (Real-time Adaptive Update) ---
    
    % 1. 查找当前实时信念 test_b 在预计算集 B 中的索引
    t_b_q = round(test_b / grid_size) * grid_size;
    [~, idx] = min(sum(abs(B - t_b_q), 2));
    act = policy(idx); % 执行策略表中的动作
    rec_policy(t) = act;
    rec_prob(t) = 1 - test_b(1); % 记录当前的受攻击怀疑度
    
    % 2. 定义当前步的信念预测转移矩阵
    P_step = zeros(T+1, T+1);
    P_step(1,1) = 1-curr_p; P_step(1,2) = curr_p;
    for i = 2:T, P_step(i, i+1) = 1; end
    P_step(T+1, 1) = 1;

    % 3. 贝叶斯观测更新逻辑
    if act > 0
        % 情况 A：采取了探测动作 (1 或 2)
        if GroundTruth(t) == 1 && rand() < DetRate(act+1)
            % 观测成功：确认为受攻击，信念分布重置为攻击期起始状态
            b_new = test_b * P_step;
            b_new(1) = 0; 
            test_b = b_new / sum(b_new); 
        else
            % 观测为正常：可能是真正常，也可能是漏报 (Miss Detection)
            b_pred = test_b * P_step;
            dr = DetRate(act+1); 
            % 贝叶斯似然修正：正常态概率保留，受攻击各态概率按 (1 - dr) 衰减
            test_b(1) = b_pred(1); 
            test_b(2:end) = b_pred(2:end) * (1 - dr); 
            test_b = test_b / sum(test_b); % 归一化
        end
    else
        % 情况 B：动作 0 (不探测)，信念仅按转移矩阵 P 进行纯概率演化
        test_b = test_b * P_step;
    end
end

%% --- 5. 可视化展示 (修正理论值输出) ---
figure('Color', 'w', 'Position', [100, 100, 1000, 800]);

% 子图 1: 频率估计对比
subplot(3,1,1); hold on;
% 绘制实测估计值
plot(0:SimTime-1, rec_p_est, 'r', 'LineWidth', 2, 'DisplayName', '估计有效频率 \hat{p}');

% --- 核心修正：计算考虑 MinGap 后的修正理论上限 ---
% 公式解释：原始 p 被 (T + MinGap - 1) 的强制占用期稀释
CorrectedEffP = TrueAtkFreq / (1 + TrueAtkFreq * (T + MinGap - 1));

yline(CorrectedEffP, 'k--', 'LineWidth', 1.5, 'DisplayName', '修正理论上限');
ylabel('频率参数', 'Interpreter', 'tex');

% 动态标题，展示当前参数
title_str = sprintf('频率动态估计 (T=%d, MinGap=%d, p_{true}=%.2f)', T, MinGap, TrueAtkFreq);
title(title_str, 'Interpreter', 'tex');

legend('Location', 'northeast', 'Interpreter', 'tex');
grid on; 
xlim([0, SimTime]); 
% 纵坐标从0开始，并根据数据动态调整上限
ylim([0, max(max(rec_p_est), CorrectedEffP) * 1.5]);

% 子图 2: 怀疑度演化
subplot(3,1,2); hold on;
diff_gt = diff([0; GroundTruth; 0]);
s_atks = find(diff_gt==1); e_atks = find(diff_gt==-1)-1;
for i=1:length(s_atks)
    patch([s_atks(i) e_atks(i) e_atks(i) s_atks(i)], [0 0 1 1], [0.9 0.9 0.9], 'EdgeColor', 'none', 'HandleVisibility', 'off');
end
plot(0:SimTime-1, rec_prob, 'b', 'LineWidth', 1.5);
ylabel('怀疑度', 'Interpreter', 'tex'); 
title('怀疑度演化 (背景灰色为 Ground Truth 攻击期)', 'Interpreter', 'tex');
grid on; ylim([-0.05 1.05]); xlim([0, SimTime]);

% 子图 3: 建议动作
subplot(3,1,3);
stairs(0:SimTime-1, rec_policy, 'm', 'LineWidth', 1.5);
ylim([-0.2 2.2]); yticks([0 1 2]); yticklabels({'无','低','高'});
ylabel('建议动作', 'Interpreter', 'tex'); xlabel('时间 (秒)', 'Interpreter', 'tex');
grid on; xlim([0, SimTime]);