%% 2.1-1：单精度、整数不可混用
a=uint32(120);
b=single(22.809);
c=73.226;
%ab=a*b
%% 2.1-2：双精度看其他
ac=a*c

bc=b*c

str="hello"
newstr=str-44.3

whos