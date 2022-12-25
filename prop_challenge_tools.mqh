#include <../Experts/mq5ea/mytools.mqh>

class PeriodData
{
public:
   int magic_number;
   datetime datetime_start;
   datetime datetime_end;
   double profit;
   double profit_max;
   double profit_min;
   void PeriodData(int magic);
   void update(void);
};

class PropChallengeCriteria
{
protected:
   PeriodData period_data[];
   double min_profit_usd;
   double max_drawdown_usd;
   int magic_number;
   ENUM_MONTH period_month;
   bool is_drawdown_passed(const PeriodData& pdata);
   bool is_profit_passed(const PeriodData& pdata);
   bool is_period_passed(const PeriodData& pdata);
  
public:
   void PropChallengeCriteria(void);
   void PropChallengeCriteria(double min_profit_usd, double max_drawdown_usd, ENUM_MONTH period_month, int magic);
   void update(void);
   bool is_current_period_drawdown_passed(void);
   bool is_current_period_profit_passed(void);
   bool is_current_period_passed(void);
   double get_results(void);
};


void PeriodData::PeriodData(int magic){
   MqlDateTime time_start, time_end;
   TimeToStruct(TimeCurrent(), time_start);
   TimeToStruct(TimeCurrent(), time_end);
   time_start.day=1;
   if(time_end.mon==4 || time_end.mon==6 || time_end.mon==9 || time_end.mon==11) time_end.day=30;
   else if(time_end.mon==2) time_end.day=28;
   else time_end.day=31;
   datetime_start = StructToTime(time_start);
   datetime_end = StructToTime(time_end);
   magic_number = magic;
   profit = 0;
   profit_max = 0;
   profit_min = 0;
}

void PeriodData::update(void){
   double _prof = 0;
   HistorySelect(datetime_start, datetime_end);
   int ndeals = HistoryDealsTotal();
   for(int i=0;i<ndeals;i++){
      ulong dealticket = HistoryDealGetTicket(i);
      HistoryDealSelect(dealticket);
      int magic = HistoryDealGetInteger(dealticket, DEAL_MAGIC);
      if(magic != magic_number) continue;
      _prof += HistoryDealGetDouble(dealticket, DEAL_PROFIT) + HistoryDealGetDouble(dealticket, DEAL_COMMISSION) + HistoryDealGetDouble(dealticket, DEAL_FEE) + HistoryDealGetDouble(dealticket, DEAL_SWAP);
   }
   profit = _prof;
   if(profit>profit_max) profit_max = profit;
   if(profit<profit_min) profit_min = profit;
}


void PropChallengeCriteria::PropChallengeCriteria(double min_profit_usd_, double max_drawdown_usd_, ENUM_MONTH period_month_, int magic){
   min_profit_usd = min_profit_usd_;
   max_drawdown_usd = max_drawdown_usd_;
   period_month = period_month_;
   magic_number = magic;
}

void PropChallengeCriteria::update(void){
   int ndata = ArraySize(period_data);
   MqlDateTime current_time;
   TimeToStruct(TimeCurrent(), current_time);
   if(ndata>0){
      MqlDateTime last_period_time;
      TimeToStruct(period_data[ndata-1].datetime_end, last_period_time);
      if(last_period_time.year==current_time.year && last_period_time.mon==current_time.mon){
         period_data[ndata-1].update();
      }else if(current_time.mon==period_month || period_month==MONTH_ALL){
         ArrayResize(period_data, ndata+1);
         period_data[ndata] = PeriodData(magic_number);
      } 
   }else if(current_time.mon==period_month || period_month==MONTH_ALL){
      ArrayResize(period_data, 1);
      period_data[0] = PeriodData(magic_number);
   }
}

bool PropChallengeCriteria::is_drawdown_passed(const PeriodData &pdata){
   bool is_passed;
   is_passed = pdata.profit_min>=-max_drawdown_usd;
   return is_passed;
}

bool PropChallengeCriteria::is_profit_passed(const PeriodData &pdata){
   bool is_passed;
   is_passed = pdata.profit_max>=min_profit_usd;
   return is_passed;
}

bool PropChallengeCriteria::is_current_period_drawdown_passed(void){
   bool is_passed = false;
   int ndata = ArraySize(period_data);
   if(ndata>0){
      is_passed = is_drawdown_passed(period_data[ndata-1]);
   }
   return is_passed;
}

bool PropChallengeCriteria::is_current_period_profit_passed(void){
   bool is_passed = false;
   int ndata = ArraySize(period_data);
   if(ndata>0){
      is_passed = is_profit_passed(period_data[ndata-1]);
   }
   return is_passed;
}

bool PropChallengeCriteria::is_period_passed(const PeriodData &pdata){
   bool is_passed;
   is_passed = is_profit_passed(pdata) && is_drawdown_passed(pdata);
   return is_passed;
}

bool PropChallengeCriteria::is_current_period_passed(void){
   bool is_passed = false;
   int ndata = ArraySize(period_data);
   if(ndata>0){
      is_passed = is_period_passed(period_data[ndata-1]);
   }
   return is_passed;
}

double PropChallengeCriteria::get_results(void){
   int ndata = ArraySize(period_data);
   double score=0;
   for(int i=0;i<ndata;i++){
      if(is_period_passed(period_data[i])) score++;
   }
   score /= ndata;
   return score;
}