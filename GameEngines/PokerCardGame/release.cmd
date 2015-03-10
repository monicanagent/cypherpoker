@echo Deploying to: 
@echo   InstantLocalLounge-web
@echo off
cd..
cd..
cd bin-output
xcopy PokerCardGame InstantLocalLounge-web\PokerCardGame /E /Y
@echo Done.