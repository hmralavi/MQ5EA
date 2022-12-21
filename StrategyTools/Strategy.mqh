#include <../Experts/mq5ea/StrategyTools/DataProvider.mqh>
//---------------------------------------------------------
enum ENUM_ORDER_TYPE_COSTUME{
   ORDER_TYPE_COSTUME_NONE = -1,
   ORDER_TYPE_COSTUME_BUY = 0,
   ORDER_TYPE_COSTUME_SELL = 1,
   ORDER_TYPE_COSTUME_BUY_LIMIT = 2,
   ORDER_TYPE_COSTUME_SELL_LIMIT = 3,
   ORDER_TYPE_COSTUME_BUY_STOP = 4,
   ORDER_TYPE_COSTUME_SELL_STOP = 5
};
//---------------------------------------------------------
struct CostumeOrder
{
   ENUM_ORDER_TYPE_COSTUME type;
   string symbol;
   double price;
   double lots;
   double sl;
   double tp;
};
//---------------------------------------------------------

class Strategy
{
protected:
   string name;
   string symbol;
   double pts;
  
public:
   void Strategy(void);
   void Strategy(string stgname, string symbolname);
   CostumeOrder on_tick(TesterDataProvider &dp);
   

};


void Strategy::Strategy(string stgname,string symbolname){
   name=stgname;
   symbol=symbolname;
   pts = SymbolInfoDouble(symbol, SYMBOL_POINT);
}


//---------------------------------------------------------
class SampleStrategy: Strategy
{
   CostumeOrder on_tick(TesterDataProvider &dp){
   CostumeOrder new_order;
   MqlRates rates[];
   dp.copy_rates(rates);
   new_order.type = ORDER_TYPE_COSTUME_BUY_LIMIT;
   new_order.price = rates[0].close - 1000*pts;
   new_order.sl = new_order.price - 200*pts;
   new_order.tp = new_order.price + 2*(new_order.price-new_order.sl);
   return new_order;
   }

};
