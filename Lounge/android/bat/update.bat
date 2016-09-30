@echo Refreshing: 
@echo   Lounge-android
@echo off
@cd..
@cd..
@echo Updating Ethereum supporting libraries, smart contracts, and utilities...
@xcopy ethereum bin-output\Lounge-android\ethereum\ /E /Y
@cd bin-output
@echo Updating core game code (PokerCardGame)...
@xcopy PokerCardGame Lounge-android\PokerCardGame\ /E /Y
@cd..
@cd Lounge\android
@echo Done.