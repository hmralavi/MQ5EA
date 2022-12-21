#include <../Experts/mq5ea/StrategyTools/Strategy.mqh>
#include <../Experts/mq5ea/StrategyTools/DataProvider.mqh>
//---------------------------------------------------------
enum ENUM_TEST_POSITION_TYPE{
   TEST_POSITION_TYPE_PENDING = 0,
   TEST_POSITION_TYPE_ACTIVE = 1,
   TEST_POSITION_TYPE_CLOSED = 2
};
//---------------------------------------------------------
class CostumeTestPosition
{
   ENUM_TEST_POSITION_TYPE type;
   string symbol;
   double price;
   double lots;
   double sl;
   double tp;
   datetime placed_date;
   datetime activated_date;
   datetime closed_date;
   double calc_profit(){return 35.4;}
};
//---------------------------------------------------------

class Agent
{
public:
   Agent(void){Print("base trading agent created");}

};
//---------------------------------------------------------
class LiveAgent: Agent
{


};

//---------------------------------------------------------
class TesterAgent: Agent
{
private:
   CostumeTestPosition positions[];
   
public:
   void run(Strategy &stg, TesterDataProvider &dp);
   double calc_profit();
   int calc_trades_total_number();
   
};


void TesterAgent::run(Strategy &stg, TesterDataProvider &dp)
{

}