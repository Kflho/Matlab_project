function [y_faulty, u_faulty] = inject_fault(y_seq, u_seq, fault_type, fault_subsys, fault_magnitude, k_fault)
% inject_fault  故障注入函数
%   在指定时间步及之后，对指定子系统注入传感器故障或执行器故障。
%   传感器故障 f_y 叠加在输出 y 上，执行器故障 f_u 叠加在输入 u 上。
%
%   故障模型（论文第 III-B 节）：
%       传感器故障:  ȳ_{ω} = y_{ω}^0 + Ψ_y · f_y
%       执行器故障:  ū_{ω} = u_{ω}^0 + Ψ_u · f_u
%
%   可检测性条件（公式 (31)-(32)）：
%       传感器: |f_y| > √(2·J_{th,ω}) / ‖Σ_{r,ω}^{-1/2} · G_{z,ω} · Ψ_y‖
%       执行器: |f_u| > √(2·J_{th,ω}) / ‖Σ_{r,ω}^{-1/2} · D_{z,ω} · Ψ_u‖
%
%   Inputs:
%       y_seq           - 正常输出时间序列，N_y × T_sim 或 cell array
%       u_seq           - 正常输入时间序列，N_u × T_sim
%       fault_type      - 故障类型：'sensor' 或 'actuator'
%       fault_subsys    - 故障注入的目标子系统索引（标量）
%       fault_magnitude - 故障幅值（标量）
%       k_fault         - 故障注入起始时刻（在此步及之后叠加故障）
%
%   Outputs:
%       y_faulty - 故障注入后的输出（与 y_seq 相同格式）
%       u_faulty - 故障注入后的输入（与 u_seq 相同格式）
%
%   Example:
%       % 在 k=500 时对子系统 1 注入传感器故障，幅值 0.5
%       [y_f, u_f] = inject_fault(y_seq, u_seq, 'sensor', 1, 0.5, 500);

%% ========================================================================
%  1. 输入验证
% ========================================================================

valid_types = {'sensor', 'actuator'};
assert(ismember(fault_type, valid_types), ...
    'fault_type 必须为 ''sensor'' 或 ''actuator''。');

assert(k_fault >= 1, 'k_fault 必须 ≥ 1。');

% 确定时间序列长度
if iscell(y_seq)
    % cell array 格式：y_seq{i} 为子系统 i 的时间序列
    T_sim_y = size(y_seq{1}, 2);
else
    T_sim_y = size(y_seq, 2);
end
T_sim_u = size(u_seq, 2);

assert(k_fault <= T_sim_y, 'k_fault (%d) 超出 y_seq 范围 (%d)。', k_fault, T_sim_y);

%% ========================================================================
%  2. 复制数据
% ========================================================================

if iscell(y_seq)
    y_faulty = y_seq;   % cell array 浅拷贝（MATLAB 的 copy-on-write）
else
    y_faulty = y_seq;
end
u_faulty = u_seq;

%% ========================================================================
%  3. 注入故障
% ========================================================================

switch fault_type
    case 'sensor'
        % ---- 传感器故障：y(i_subsys, k_fault:end) += f_y ----
        if iscell(y_faulty)
            % cell 格式：每个子系统独立
            assert(fault_subsys <= length(y_faulty), ...
                'fault_subsys (%d) 超出子系统数量 (%d)。', ...
                fault_subsys, length(y_faulty));
            if ~isempty(y_faulty{fault_subsys})
                y_faulty{fault_subsys}(:, k_fault:end) = ...
                    y_faulty{fault_subsys}(:, k_fault:end) + fault_magnitude;
            else
                warning('Inject_fault: 子系统 %d 无传感器，无法注入传感器故障。', ...
                    fault_subsys);
            end
        else
            % 矩阵格式：y_seq 的每一行对应一个子系统输出
            assert(fault_subsys <= size(y_faulty, 1), ...
                'fault_subsys (%d) 超出 y_seq 行数 (%d)。', ...
                fault_subsys, size(y_faulty, 1));
            y_faulty(fault_subsys, k_fault:end) = ...
                y_faulty(fault_subsys, k_fault:end) + fault_magnitude;
        end

        fprintf('[inject_fault] 传感器故障: 子系统 %d, 幅值 %.4f, 时刻 k ≥ %d\n', ...
            fault_subsys, fault_magnitude, k_fault);

    case 'actuator'
        % ---- 执行器故障：u(:, k_fault:end) += f_u ----
        % 执行器故障影响全局输入（因为输入是共享的）
        u_faulty(:, k_fault:end) = u_faulty(:, k_fault:end) + fault_magnitude;

        fprintf('[inject_fault] 执行器故障: 幅值 %.4f, 时刻 k ≥ %d（影响全部子系统）\n', ...
            fault_magnitude, k_fault);
end

end
