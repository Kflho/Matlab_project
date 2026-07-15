function [y_faulty, u_faulty] = Inject_fault(k, y_nominal, u_nominal, fault_type, fault_subsys, fault_magnitude)
% Inject_fault  故障注入函数
%   在指定时间步 k 为指定子系统注入传感器故障 f_y 或执行器故障 f_u，
%   返回故障叠加后的输出 y_faulty 与输入 u_faulty。
%
%   Inputs:
%       k              - 当前时间步
%       y_nominal      - 正常输出信号，来自Simulink仿真或监测数据（cell array）
%       u_nominal      - 正常输入信号，来自Simulink仿真或监测数据（cell array）
%       fault_type     - 故障类型：'sensor'（传感器故障 f_y）或 'actuator'（执行器故障 f_u）
%       fault_subsys   - 故障注入的目标子系统索引
%       fault_magnitude - 故障幅值（需满足公式 (31)-(32) 的可检测性边界）
%
%   Outputs:
%       y_faulty - 注入故障后的输出信号
%       u_faulty - 注入故障后的输入信号

% TODO: 实现故障注入逻辑，支持传感器故障与执行器故障
end
