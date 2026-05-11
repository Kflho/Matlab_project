function actions_found = solve_pomdp(C_0, C_A, T, p, grid_size)
    % 该函数接收代价参数，返回该策略中包含哪些动作
    gamma = 0.95;
    
    % --- 1. 信念空间枚举 ---
    B = [1, zeros(1, T)]; 
    P = zeros(T+1, T+1);
    P(1,1) = 1-p; P(1,2) = p;
    for i = 2:T, P(i, i+1) = 1; end
    P(T+1, 1) = 1; 

    for level = 1:50 % 限制层级加快搜索
        old_n = size(B, 1);
        B_next = [B * P; (B * P).*(ones(size(B,1),1)*[0, ones(1,T)])];
        % 简化版枚举加速搜索
        B = [B; B_next];
        B = round(B / grid_size) * grid_size;
        B = unique(round(B, 8), 'rows');
        if size(B, 1) == old_n || size(B, 1) > 1000, break; end
    end
    n_beliefs = size(B, 1);

    % --- 2. 预计算与值迭代 ---
    next_idx_unobs = zeros(n_beliefs, 1);
    for i = 1:n_beliefs
        b_n0 = round(B(i,:) * P / grid_size) * grid_size;
        [~, next_idx_unobs(i)] = min(sum(abs(B - b_n0), 2));
    end

    V = zeros(n_beliefs, 1); policy = zeros(n_beliefs, 1);
    for iter = 1:200
        V_old = V;
        for i = 1:n_beliefs
            b = B(i, :);
            imm = b(1)*C_0 + sum(b(2:end))*C_A;
            q0 = imm(1) + gamma * V_old(next_idx_unobs(i));
            q_rest = imm(2:3) + gamma * V_old(1); % 检测即复位
            [V(i), best_a] = min([q0, q_rest]);
            policy(i) = best_a - 1;
        end
        if max(abs(V - V_old)) < 1e-4, break; end
    end
    
    % 返回策略中出现的唯一动作集合
    actions_found = unique(policy);
end