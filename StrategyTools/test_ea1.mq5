#include <../Experts/mq5ea/StrategyTools/TestClass.mqh>
//---------------------------------------------------------

void test_func(B|C &inp){
   inp.pr();

}

int OnInit()
{
A a;
A *b=new B();
A *c=new C();
test_func(b);
return(INIT_SUCCEEDED);
}

//---------------------------------------------------------

void OnDeinit(const int reason)
{


}

//---------------------------------------------------------


void OnTick()
{


}
