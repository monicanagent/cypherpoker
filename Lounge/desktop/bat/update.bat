@echo Refreshing: 
@echo   Lounge-desktop
@echo off
@cd..
@cd..
@echo Updating Ethereum supporting libraries, smart contracts, and utilities...
@xcopy ethereum\ethereumjslib bin-output\Lounge-desktop\ethereum\ethereumjslib\ /E /Y
@xcopy ethereum\solidity bin-output\Lounge-desktop\ethereum\solidity\ /E /Y
@cd bin-output
@echo Updating core game code (PokerCardGame)...
@xcopy PokerCardGame Lounge-desktop\PokerCardGame\ /E /Y
@cd..
@cd Lounge\desktop
@echo Done.