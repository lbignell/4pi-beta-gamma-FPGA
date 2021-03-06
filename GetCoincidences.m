%This function will take a data matrix (see DecodeData.m) and
%determine the single, double, and coincidence counts (and the live and
%real times) in either coincidence or anti-coincidence modes with
%user-defined dead time and coincidence resolving time.

%NB: A system-wide dead time is currently used, but that doesn't mean that
%(in principle) you couldn't have unequal dead times in the beta and gamma
%channels. It would be worth investigating what effect this extension may
%have.

%Inputs: Data = data matrix (columns are [chan1 chan2 time timeout]);
%Ch1Delay = the delay to be imposed on Ch1 events (nanoseconds);
%DT = Dead Time (nanoseconds);
%ResTime = Coincidence resolving time (nanoseconds);
%IsAntiCoinc = if true, use anti-coincidence, otherwise use regular
%coincidence;
%IsExtDT = if true, dead time is extending, otherwise use fixed dead time.

function [Channel1 Channel2 UncorrCh1 UncorrCh2 Coincidences Tlive Treal] ...
    = GetCoincidences(Data, Ch1Delay, DT, ResTime, IsAntiCoinc, IsExtDT)

if ResTime>DT
    disp('ERROR: The coincidence resolving time is greater than the dead time!');
    %return;
end

TimeoutSum = sum(Data(:,4));
if TimeoutSum ~= 0
    disp(sprintf('WARNING: there were %d timeouts in the data set. Please carefully review the data before proceeding!', TimeoutSum));
end

TickLength = 10;%40MHz clock rate so 25 nanosecond period.
PrevCh1 = false;
PrevCh2 = false;
Ch1 = false;
Ch2 = false;
Tinit = Data(1,3);
Tfinal = max(Data(size(Data(:,3)),3));
Treal = (Tfinal-Tinit)*(TickLength*1E-9);%Real time in seconds
DTtally = 0;
State = 3; %1=Coinc window, 2=Dead, 3=Live
IsCoincidence = false;
CoincWinEnd = 0;
DTEnd = 0;
TotCh1 = 0;
TotCh2 = 0;
TotCoinc = 0;
ThisTime = 0;
Tlive = 0;
UncorrCh1 = 0;
UncorrCh2 = 0;
ACflag1 = false;
ACflag2 = false;
NumSimultaneous = 0;

disp(sprintf('Number of Events to analyse = %i',max(size(Data(:,1)))));

for i = 1:max(size(Data(:,1)))
    %disp(' ');
    %disp('NEW LINE');
    %disp(sprintf('Ch1 = %i, Ch2 = %i, Time(ns) = %d, Timeout? = %i', ...
    %    Data(i,1), Data(i,2), (Data(i,3)*TickLength), Data(i,4)));
    Ch1 = Data(i,1);
    Ch2 = Data(i,2);
    ThisTime = Data(i,3)*TickLength;%Time of event in nanoseconds.
    if (Ch1)&&(~Ch2)
        %A simple Ch1 event, delay it!
        ThisTime = ThisTime + Ch1Delay;
    end
    if ~(IsAntiCoinc) %regular coincidence measurement
        if State == 1 %In resolving time window
            %disp('Checking resolving time');
            if ThisTime<CoincWinEnd
                if ~(IsCoincidence)%Check if coinc has already been counted
                    %disp('Possible coincidence event!');
                    if (PrevCh1&&Ch2)
                        %Increment Ch2 and Coinc.
                        TotCh2 = TotCh2 + 1;
                        TotCoinc = TotCoinc + 1;
                        IsCoincidence = true;
                        %disp('Coincidence 1->2');
                    elseif (PrevCh2&&Ch1)
                        %Increment Ch1 and Coinc.
                        TotCh1 = TotCh1 + 1;
                        TotCoinc = TotCoinc + 1;
                        IsCoincidence = true;
                        %disp('Coincidence 2->1');
                    else
                        %disp('Single channel repeated within coinc res time');
                    end
                end
            else %Not in coinc res time, probably in DT, change to that.
                State = 2;
                IsCoincidence = false;
                PrevCh1 = 0;
                PrevCh2 = 0;
                %disp('Not in res time window');
            end
        end
        if State == 2 %In dead time
            %disp('Checking dead time');
            if ThisTime<DTEnd %Still dead?
                if IsExtDT
                    DTEnd = ThisTime + DT;
                    %Go to next line
                    %disp(sprintf('Dead time extended to %d nanoseconds', DTEnd));
                else
                    %Do nothing, next line.
                    %disp('Count occurred in non-extending DT');
                end
            else %No longer dead, reset system to Live.
                State = 3;
                %disp('Count occurred after dead time');
            end
        end
        if State == 3 %System is live and we have a count!
            %disp('Count occurred in live time, processing...');
            CoincWinEnd = ThisTime + ResTime;
            Tlive = Tlive + (ThisTime - DTEnd);
            if (ThisTime-DTEnd)<0
                disp('WARNING, the System is live when it should be dead!');
                disp(sprintf('ThisTime - DTEnd = %d', (ThisTime-DTEnd)));
                disp(sprintf('Tlive = %d', Tlive));
                disp('This could be caused by the file having been appended to by a new acquisition');
            end
            DTEnd = CoincWinEnd + DT;
            %disp(sprintf('Tlive = %d ns, Coinc Win End = %d ns, DTend = %d', ...
            %    Tlive, CoincWinEnd, DTEnd));
            State = 1;
            %Check first whether it is a coincidence
            if (Ch1&&Ch2)
               TotCh1 = TotCh1 + 1;
               TotCh2 = TotCh2 + 1;
               TotCoinc = TotCoinc + 1;
               IsCoincidence = true;
               %disp('Simultaneous Coincidence');
               NumSimultaneous = NumSimultaneous + 1;
            elseif Ch1
               TotCh1 = TotCh1 + 1;
               PrevCh1 = 1;
               %disp(sprintf('Chan1 count, TotCh1 = %i', TotCh1));
            elseif Ch2
               TotCh2 = TotCh2 + 1;
               PrevCh2 = 1;
               %disp(sprintf('Chan1 count, TotCh2 = %i', TotCh2));
            else %Something ent wrong...
               disp('ERROR: an unexpected event was encountered!');
               disp(sprintf('Ch1 = %i, Ch2 = %i, Time(ticks) = %d, Timeout? = %i', ...
                   Data(i,1), Data(i,2), Data(i,3), Data(i,4)));
               return;
            end
        end
   else %Anti-coincidence
       if State == 2%Dead
           if ThisTime<DTEnd%Still in DT
               %disp('Count occurred during DT');
               if IsExtDT
                   DTEnd = ThisTime + DT;
                   %disp(sprintf('Extended DT to %d ns', DTEnd));
               end
               if (Ch1&&Ch2)
                   ACflag1 = 0;
                   ACflag2 = 0;
                   %disp('Correlated Events, unsetting AC flags');
               elseif Ch1
                   ACflag2 = 0;
                   %disp('Ch1 count in DT');
               elseif Ch2
                   ACflag1 = 0;
                   %disp('Ch2 count in DT');
               else
               %Why are we in dead time?
               disp('ERROR! The system is dead when there are no counts registered!');
               disp(sprintf('DTEnd = %d', DTEnd));
               disp(sprintf('Ch1 = %i, Ch2 = %i, Time(ticks) = %d, Timeout? = %i', ...
                   Data(i,1), Data(i,2), Data(i,3), Data(i,4)));
               return;
               end
           else %dead time is finished, tally any Anti-coincidences
               UncorrCh1 = UncorrCh1 + ACflag1;
               UncorrCh2 = UncorrCh2 + ACflag2;
               State = 3;
               %disp(sprintf('DT is over!, UncorrCh1 = %i, UncorrCh2 = %i', ...
               %    UncorrCh1, UncorrCh2));
           end
       end
       if State == 3%live (initialised to this)
            %disp('Count occurred in Live Time.');
            Tlive = Tlive + (ThisTime - DTEnd);
            if (ThisTime-DTEnd)<0
                disp('WARNING, the System is live when it should be dead!')
                disp(sprintf('ThisTime - DTEnd = %d', (ThisTime-DTEnd)));
                %disp(sprintf('Tlive = %d', Tlive));
                disp('This could be caused by the file having been appended to by a new acquisition');
            end
            DTEnd = ThisTime + DT;
            State = 2;
            %disp(sprintf('Tlive = %d, DTEnd = %d', Tlive, DTEnd));
            if (Ch1&&Ch2) %Simultaneous
                TotCh1 = TotCh1 + 1;
                TotCh2 = TotCh2 + 1;
                ACflag1 = 0;
                ACflag2 = 0;
                %disp(sprintf('Simultaneous! TotCh1 = %i, TotCh2 = %i', ...
                %    TotCh1, TotCh2));
            elseif Ch1
                TotCh1 = TotCh1 + 1;
                ACflag1 = 1;
                ACflag2 = 0;
                %disp(sprintf('Ch1! TotCh1 = %i', TotCh1));
            elseif Ch2
                TotCh2 = TotCh2 + 1;
                ACflag1 = 0;
                ACflag2 = 1;
                %disp(sprintf('Ch2! TotCh2 = %i', TotCh2));
            else
               disp('ERROR: an unexpected event was encountered!');
               disp(sprintf('Ch1 = %i, Ch2 = %i, Time(ticks) = %d, Timeout? = %i', ...
                   Data(i,1), Data(i,2), Data(i,3), Data(i,4)));
               return;
            end
       end
    end

end

Channel1 = TotCh1;
Channel2 = TotCh2;
Coincidences = TotCoinc;
Tlive = Tlive*(1E-9);
if NumSimultaneous~=0
    disp('Warning: Simultaneous Coincidences were detected. If the Ch1 delay > coinc resolving time you may need to use GetCoincidence_Accurate instead');
    disp(sprintf('Number of Simultaneous coincidences = %i', NumSimultaneous));
end
disp(sprintf('Tlive = %.4f seconds', Tlive));
disp(sprintf('Treal = %.4f seconds', Treal));
disp(sprintf('Ch1 = %i counts', Channel1));
disp(sprintf('Ch2 = %i counts', Channel2));
disp(sprintf('Uncorrelated Ch1 = %i counts', UncorrCh1));
disp(sprintf('Uncorrelated Ch2 = %i counts', UncorrCh2));
disp(sprintf('Coincidence = %i counts', Coincidences));
end