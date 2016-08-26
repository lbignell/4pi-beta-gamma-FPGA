%A simplified time spec
function TimeGap = SimpleTimeGap(Data)
prevtime = 0;
TimeGap = zeros(size(Data(:,3)));
for i = 1:max(size(Data(:,1)))
    TimeGap(i) = Data(i,3)-prevtime;
    prevtime = Data(i,3);
end
end
