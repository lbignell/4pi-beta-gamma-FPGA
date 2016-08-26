%This is a function to determine the coincidence timing spectrum.

function timespec = GetTimeSpec(Data)

%Need to preallocate timespec; each bin is 25 ns wide (can always rebin).
%Will make it -100 uSec to +100 uSec to cover widest reasonable range
%(aside from special cases such as metastable states). Therefore I need
%100000x2/25 bins = 8000 (zero is bin 4000).

timespec = zeros(8000,1);
PrevCh1 = 0;
PrevCh2 = 0;
theBin = 0;
thistime = 0;

for i = 1:max(size(Data(:,1)))
    if (Data(i,1)&&Data(i,2))%Simultaneous
        timespec(4000) = timespec(4000) + 1;
        disp('simultaneous!');
    elseif Data(i,1) %GammaCount
        if (PrevCh2~=0) %Channel 2 was last.
            thistime = Data(i,3) - PrevCh2;
            theBin = thistime+4000;%convert ticks to ns
            if (0<theBin)&&(theBin<8001)
                timespec(theBin) = timespec(theBin) + 1;
            end
            PrevCh2 = 0;
        else
            %No Ch2 since last coinc, record start.
            PrevCh1 = Data(i,3);
        end
    elseif Data(i,2) %BetaCount
        if (PrevCh1~=0) %Chan1 was last
            thistime = PrevCh1-Data(i,3);
            theBin = thistime+4000;
            if (0<theBin)&&(theBin<8001)
                timespec(theBin) = timespec(theBin)+1;
            end
            PrevCh1 = 0;
        else %Record start
            PrevCh2 = Data(i,3);
        end
    end
end
end