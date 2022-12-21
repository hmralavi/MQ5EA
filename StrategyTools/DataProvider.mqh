class DataProvider
{


};
//---------------------------------------------------------
class LiveDataProvider: DataProvider
{

};
//---------------------------------------------------------
class TesterDataProvider: DataProvider
{
protected:
   string symbol;
   datetime start_date;
   datetime end_date;
   ENUM_TIMEFRAMES tf;
   MqlRates all_rates[];  // index 0 is oldest candle
   MqlTick all_ticks[];  // index 0 is oldest tick
   int current_tick_index;
   
public:
   void TesterDataProvider(string symbol, ENUM_TIMEFRAMES timeframe, datetime startdate, datetime enddate);
   void goto_next_tick();
   void copy_rates(MqlRates &rates[], int start=0, int count=-1);      
};

void TesterDataProvider::TesterDataProvider(string symbol_, ENUM_TIMEFRAMES timeframe, datetime startdate, datetime enddate){
   symbol = symbol_;
   tf = timeframe;
   start_date = startdate;
   end_date = enddate;
   current_tick_index = 0;
   return;

}

void TesterDataProvider::copy_rates(MqlRates &rates[], int start=0, int count=-1){


}

void TesterDataProvider::goto_next_tick(void){
   current_tick_index++;

}