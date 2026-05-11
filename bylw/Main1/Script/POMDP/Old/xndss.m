clear; clc;

% 固定系统参数
T = 15;             
p = 0.01;
grid_size = 0.01;

results_count = 0;
max_results = 8;   % 输出 8 组候选参数

fprintf('%% --- 搜索到的候选参数组合 ---\n\n');

% 开始循环搜索
for c0_low = 30:10:70
    for c0_high = (c0_low + 40):20:160
        for ca_low = 400:100:800
            for ca_high = 10:20:100
                
                C0_test = [5, c0_low, c0_high];
                CA_test = [1200, ca_low, ca_high];
                
                % 调用求解器 (需确保 solve_pomdp.m 在路径下)
                acts = solve_pomdp(C0_test, CA_test, T, p, grid_size);
                
                % 检查是否包含 0, 1, 2
                if all(ismember([0, 1, 2], acts))
                    results_count = results_count + 1;
                    
                    % 格式化输出，方便直接复制
                    fprintf('%% 组合 %d\n', results_count);
                    fprintf('C_0 = [%d, %d, %d];\n', C0_test);
                    fprintf('C_A = [%d, %d, %d];\n\n', CA_test);
                    
                    if results_count >= max_results
                        return; 
                    end
                end
            end
        end
    end
end

if results_count == 0
    fprintf('%% 未找到符合条件的组合，请尝试调整搜索步长。\n');
end