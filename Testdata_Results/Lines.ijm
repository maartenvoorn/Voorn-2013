//Automatically generated file for control lines for multiscale Hessian analysis
arguments=getArgument();
avgmat=substring(arguments,0,5);
fracthresh=substring(arguments,5,10);
//____________________________________
makeRectangle( 0 , 0 , 138 , 84 );
run("Set...", "value=avgmat");
makeRectangle( 2 , 2 , 2 , 10 );
run("Set...", "value=fracthresh");
makeRectangle( 10 , 2 , 4 , 20 );
run("Set...", "value=fracthresh");
makeRectangle( 22 , 2 , 6 , 30 );
run("Set...", "value=fracthresh");
makeRectangle( 38 , 2 , 8 , 40 );
run("Set...", "value=fracthresh");
makeRectangle( 58 , 2 , 10 , 50 );
run("Set...", "value=fracthresh");
makeRectangle( 82 , 2 , 12 , 60 );
run("Set...", "value=fracthresh");
makeRectangle( 0 , 0 , 138 , 84 );		//Repetition required to pass box to main code
