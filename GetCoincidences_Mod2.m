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
%NB: The Channel 1 delay MUST be positive!!!
%DT = Dead Time (nanoseconds);
%ResTime = Coincidence resolving time (nanoseconds);
%IsAntiCoinc = if true, use anti-coincidence, otherwise use regular
%coincidence;
%IsExtDT = if true, dead time is extending, otherwise use fixed dead time.

function [Channel1 Channel2 UncorrCh1 UncorrCh2 Coincidences Tlive Treal] ...
    = GetCoincidences(Data, Ch1Delay, DT, ResTime, IsAntiCoinc, IsExtDT)

if Ch1Delay<0
    disp('ERROR: The delay on Channel 1 must be POSITIVE!');
    Channel1 = 0;
    Channel2 = 0;
    UncorrCh1 = 0;
    UncorrCh2 = 0;
    Coincidences = 0;
    Tlive = 0;
    Treal = 0;
    return;
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
i = 1;
DelayedEvents = [100 false 0 0];
hazDelayedEvents = false;
ErrorTally = 0;
SkipAnalysis = false;
j = 0;%Counter for delayed event to PROCESS
k = 1;%Counter for delayed event to WRITE

disp(sprintf('Number of Events to analyse = %i',max(size(Data(:,1)))));

while i<max(size(Data(:,1)))
    %disp(' ');
    %disp('NEW LINE');
    %disp(sprintf('Ch1 = %i, Ch2 = %i, Time(ns) = %d, Timeout? = %i', ...
    %    Data(i,1), Data(i,2), (Data(i,3)*TickLength), Data(i,4)));
    %disp(sprintf('hazDelayedEvents = %i',hazDelayedEvents));
    %disp(sprintf('TotCh1 = %i, TotCh2 = %i, TotCoinc = %i, Tlive = %d', TotCh1, TotCh2, TotCoinc, Tlive));
    %DelayedEvents
    disp(sprintf('Line Number = %i', i));
    
    %need to start with the presumption that we won't skip the analysis.
    SkipAnalysis = false;
    %Collect the next data to be analysed
    if hazDelayedEvents
    %Need to check whether there are any events ocurring prior to the
    %delayed event...
        if ((Data(i,3)*TickLength)>DelayedEvents(j,3))&&(j~=0)
            %DON'T iterate the counter!
            %Process the delayed event.
            Ch1 = DelayedEvents(j,1);
            Ch2 = DelayedEvents(j,2);
            ThisTime = DelayedEvents(j,3);
            %don't actually use 4th row...
            if(DelayedEvents(j+1,3)==0)
                %unset the delayed events flag...
                hazDelayedEvents = false;
                %disp(sprintf('DelayedEvents; Ch1=%i, Ch2=%i, ticks=%d',...
                %    DelayedEvents(1,1), DelayedEvents(1,2), DelayedEvents(1,3)));
            else
                %Move to next delayed event
                j = j+1;
                %DelayedEvents
            end
        else
            Ch1 = Data(i,1);
            Ch2 = Data(i,2);
            ThisTime = Data(i,3)*TickLength;%Time of event in nanoseconds.
            if (Ch1)
                if ~(Ch1&&Ch2)
                    %Unless there's a beta, need to skip the data analysis
                    SkipAnalysis = true;
                end
            %Need to delay ONLY the gamma, and process the beta (if there is one).
            %This will be our flag to account for the fact that these
            %aren't truly coincident, and we need to give them different
            %times.
                hazDelayedEvents = true;
                Ch1 = 0;%for the event to be processed.
                %Write to line k
                DelayedEvents(k,1) = true;
                DelayedEvents(k,2) = false;
                DelayedEvents(k,3) = ThisTime + Ch1Delay;
                DelayedEvents(k,4) = Data(i,4);
                k = k+1;
            end
            %Process the recorded event first. Iterate the counter.
            i = i + 1;
        end
    else
        Ch1 = Data(i,1);
        Ch2 = Data(i,2);
        ThisTime = Data(i,3)*TickLength;%Time of event in nanoseconds.
        if (Ch1)
            if ~(Ch1&&Ch2)
                    %Unless there's a beta, need to skip the data analysis
                    SkipAnalysis = true;
            end
        %Need to delay ONLY the gamma, and process the beta (if there is one).
        %This will be our flag to account for the fact that these
        %aren't truly coincident, and we need to give them different
        %times.
            hazDelayedEvents = true;
            Ch1 = 0;%for the event to be processed.
                %disp('Writing to Delayed Events (there currently are none)');
                %disp(sprintf('before write; Ch1=%i, Ch2=%i, ticks=%d',...
                %    DelayedEvents(1,1), DelayedEvents(1,2), DelayedEvents(1,3)));
                %Overwrite initialised value (there'll only ever be 1 row)
                DelayedEvents(k,1) = true;
                DelayedEvents(k,2) = false;
                DelayedEvents(k,3) = ThisTime + Ch1Delay;
                DelayedEvents(k,4) = Data(i,4);
                k = k+1;
                %disp(sprintf('After write; Ch1=%i, Ch2=%i, ticks=%d',...
                %    DelayedEvents(1,1), DelayedEvents(1,2), DelayedEvents(1,3)));
        end
        
        %No delayed events, iterate i and read out next line as normal.
        i = i + 1;

    end
    
    %Start of the data processing
    if ~SkipAnalysis
        %disp('Doing Coinc Analysis.')
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
           % disp(sprintf('Tlive = %d ns, Coinc Win End = %d ns, DTend = %d', ...
            %    Tlive, CoincWinEnd, DTEnd));
            State = 1;
            %Check first whether it is a coincidence
            if (Ch1&&Ch2)
               TotCh1 = TotCh1 + 1;
               TotCh2 = TotCh2 + 1;
               TotCoinc = TotCoinc + 1;
               IsCoincidence = true;
               disp('Simultaneous Coincidence');
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
                   Ch1, Ch2, ThisTime, Data(i,4)));
                             
               disp(sprintf('Current Tally: Ch1 = %i, Ch2 = %i, Coinc = %i, Tlive = %d', ...
                   TotCh1, TotCh2, TotCoinc, Tlive));
               ErrorTally = ErrorTally + 1;
               disp(sprintf('Error tally = %i', ErrorTally));
               disp(sprintf('result of Ch1&&Ch2 = %i', (Ch1&&Ch2)));
               disp(sprintf('result of Ch1&&true = %i', (Ch1&&true)));
               disp(sprintf('result of Ch2&&true = %i', (Ch2&&true)));
               disp(sprintf('Class of Ch1 = %s', class(Ch1)));
               %return;
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
    %Go back and read in next line...
end

Channel1 = TotCh1;
Channel2 = TotCh2;
Coincidences = TotCoinc;
Tlive = Tlive*(1E-9);
disp(sprintf('Tlive = %.4f seconds', Tlive));
disp(sprintf('Treal = %.4f seconds', Treal));
disp(sprintf('Ch1 = %i counts', Channel1));
disp(sprintf('Ch2 = %i counts', Channel2));
disp(sprintf('Uncorrelated Ch1 = %i counts', UncorrCh1));
disp(sprintf('Uncorrelated Ch2 = %i counts', UncorrCh2));
disp(sprintf('Coincidence = %i counts', Coincidences));
end