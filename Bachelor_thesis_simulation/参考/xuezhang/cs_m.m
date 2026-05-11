 figure;
r_s=res_three(m_u,m_y_false,m_y_false,An,Bn,Cn,Dn,4,Alpha);
J=cal_plot(m_u,m_y,r_s,4);

f8=figure(8);t=2:2:2*length(m_u);plot(t,m_u(1,:));legend('输入信号1');
xlabel('t/s');ylabel('Q/(cm^3/s)');set(f8,'Color','w');

f8=figure(8);t=2:2:2*length(m_u);plot(t,m_u(2,:));hold on;plot(t,m_u(1,:));legend('输入信号2','输入信号1');
xlabel('t/s');ylabel('Q/(cm^3/s)');set(f8,'Color','w');

figure;
deta_y=m_y_false-m_y;
t=2:2:2*length(m_y);
plot(t,m_y_false);
plot(t,deta_y);

[H_s1,var_s]=Att(m_u,m_y,4);
G_s=[1	0	0
0	1	0
0	0	1
-0.008	0	0.008
0	-0.0194	0.008
0.008	0.008	-0.0168
0.00014	0	-0.00021
0	0.00044	-0.0003
-0.0002	-0.0003	0.0004
0	0	0
0	0	0
0	0	0];


[Uz1,Sz1,Vz1]=recsvd_fop(zk,zp,Uz0,Sz0,Vz0,a,nn)


