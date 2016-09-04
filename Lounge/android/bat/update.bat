@echo Refreshing: 
@echo   Lounge-android
@echo off
@cd..
@cd..
@echo Updating smart contract JavaScript library for Ethereum (ethereumjslib)...
@cd smart-contracts
@xcopy ethereumjslib ..\bin-output\Lounge-android\ethereum\ /E /Y
@cd..
@cd bin-output
@echo Updating core game code (PokerCardGame)...
@xcopy PokerCardGame Lounge-android\PokerCardGame\ /E /Y
@cd..
@cd Lounge
@cd android
@echo Done.