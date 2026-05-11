%--------------------------------------------------------------------------
% fault scenario
%--------------------------------------------------------------------------

% f_scenario = 'leak1';
% fault_time = 7000;

switch f_scenario
    case 'leak1'
        F_leak1_time = fault_time;      % sec
        F_leak1_gain = fault_gain;               % 5 %
    case 'leak2'
        F_leak2_time = fault_time;      % sec
        F_leak2_gain = fault_gain;              % 10 %
    case 'leak3'
        F_leak3_time = fault_time;      % sec
        F_leak3_gain = fault_gain;              % 15 %   
    case 'sensor1'
        F_sensor1_time = fault_time;    % sec
        F_sensor1_offset = fault_gain;           % 5 cm
    case 'sensor2'
        F_sensor2_time = fault_time;    % sec
        F_sensor2_offset = fault_gain;          % 5 cm
    case 'sensor3'
        F_sensor3_time = fault_time;    % sec
        F_sensor3_offset = fault_gain;           % 5 cm
    case 'plug13'
        F_plugg13_time = fault_time;    % sec
        F_plugg13_gain = fault_gain;             % 5 %
    case 'plug32'
        F_plugg32_time = fault_time;    % sec
        F_plugg32_gain = fault_gain;            % 10 %
    case 'plug20'
        F_plugg20_time = fault_time;    % sec
        F_plugg20_gain = fault_gain;            % 15 %
    case 'actuator1'
        F_pump1_time = fault_time;      % sec
        F_pump1_gain = fault_gain;              % 90 %
    case 'actuator2'
        F_pump2_time = fault_time;      % sec
        F_pump2_gain = fault_gain;              % 80 %
end
attack_time=70000;
m_ramp1=3e-4;
m_ramp2=0;
m_satu=1;
m_satu1=460;
m_satu2=160;
m_satu3=320;
T_attack=1000/(2*pi);
sim 'Example_Faulty_DataGen.slx'


m_u = Exp_u.signals.values(round((1e3+1)/m_ts):round(m_steps/m_ts),:)';
m_y = Exp_y.signals.values(round((1e3+1)/m_ts):round(m_steps/m_ts),:)'; 
m_y_false = exp_y_false.signals.values(round((1e3+1)/m_ts):round(m_steps/m_ts),:)';






