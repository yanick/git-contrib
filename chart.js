const co = require('co');
const generate = require('node-chartist');
const contribs = require('./contributors.json');
const _ = require( 'lodash' );
 

    let names = _.uniq( _.flatMap( contribs, c => _.keys(c.contributors) ) );
    let versions = contribs.map( c => c.version );

    let stack = [];

    let series = names.map( name => {
        let value = contribs.map(
            (c,i) => {
//                return c.contributors[name]
                if ( c.contributors[name] ) {
                    stack[i] = ( stack[i] || 0 ) + ( c.contributors[name] || 0 );
                    return stack[i];
                }
                return null;
                return c.contributors[name] || 0
            }
        )
        return { name, value }
    });

    series.reverse();

  // options object 
  const options = {width: 1200, height: 600, showArea: true, showPoint: false, showLine: false, stackBars: true };
  const data = {
    labels: versions,
    series 
  };
console.log(`
<html>
    <head>
        <link rel="stylesheet" type="text/css"
            href="node_modules/chartist/dist/chartist.css" />
    </head>
    <body>
        `);
  const bar = generate('line', options, data); //=> chart HTML 

  bar.then( doc => console.log(doc) ).then( () => console.log(`
    </body></html>
              `));

 

