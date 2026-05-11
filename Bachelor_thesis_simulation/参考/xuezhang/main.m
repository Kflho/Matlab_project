% clear all, close all


run('init_model.m');
% f_scenario = leak1/2/3, sensor1/2/3, plug13/32/20, actuator1/2
f_scenario = 'leak1';
fault_time = 70000;  % sec
fault_gain = 3.5;  % fault gain or offset(sensor)
run('fault_scenario.m');

% H_s=Att(m_u,m_y,4);
r_s=res_three(m_u,m_y,m_y_false,An,Bn,Cn,Dn,4,Alpha);
J=cal_plot(m_u,m_y,r_s,4);

