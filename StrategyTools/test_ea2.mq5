#include <../Experts/mq5ea/StrategyTools/TestClass.mqh>
//---------------------------------------------------------


int OnInit()
{
// initialize a test+live agent and a test+live dataprovider 
return(INIT_SUCCEEDED);
}

//---------------------------------------------------------

void OnDeinit(const int reason)
{


}

//---------------------------------------------------------


void OnTick()
{
/* on a new candle or whatever, if you want to do backtesting,
first set the agent and the dataprovider on backtesting mode.
on the other hand, if you want to do live trading, set them on live mode.
*/
}



void main_strategy(Agent &agent, DataProvider &dataprovider){



}