@echo Refreshing: 
@echo   Lounge-desktop
@echo off
@cd..
@cd..
@echo Updating smart contract JavaScript library for Ethereum (ethereumjslib)...
@cd smart-contracts
@xcopy ethereumjslib ..\bin-output\Lounge-desktop\ethereum\ /E /Y
@cd..
@cd bin-output
@echo Updating core game code (PokerCardGame)...
@xcopy PokerCardGame Lounge-desktop\PokerCardGame\ /E /Y
@cd..
@cd Lounge
@cd desktop
@echo Done.