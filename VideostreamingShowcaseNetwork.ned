package inet.showcases.emulation.videostreaming;

import inet.networklayer.configurator.ipv4.Ipv4NetworkConfigurator;
import inet.node.ethernet.Eth100M;
import inet.node.ethernet.EthernetSwitch;
import inet.node.inet.Router;
import inet.node.inet.StandardHost;
import inet.visualizer.common.IntegratedVisualizer;

network VideoStreamingShowcase
{
    parameters:
        @display("bgb=1100,700");
    submodules:
        configurator: Ipv4NetworkConfigurator {
            parameters:
                @display("p=100,100;is=s");
        }
        visualizer: IntegratedVisualizer {
            parameters:
                @display("p=100,200;is=s");
        }
        switch1: EthernetSwitch {
            parameters:
                @display("p=300,300");
        }
        switch2: EthernetSwitch {
            parameters:
                @display("p=700,300");
        }
        router: Router {
            parameters:
                @display("p=500,300");
        }
        host1: StandardHost {
            parameters:
                @display("p=100,300");
        }
        host2: StandardHost {
            parameters:
                @display("p=900,300");
        }

        // Novo roteador paralelo
        //router2: Router {
        //    parameters:
        //        @display("p=500,550");
       // }

        // Hosts internos conectados ao router2
       // host3: StandardHost {
        //    parameters:
       //         @display("p=300,550");
       // }
       // host4: StandardHost {
       //     parameters:
      //          @display("p=700,550");
      //  }

    connections allowunconnected:
        host1.ethg++ <--> Eth100M <--> switch1.ethg++;
        switch1.ethg++ <--> Eth100M <--> router.ethg++;
        router.ethg++ <--> Eth100M <--> switch2.ethg++;
        switch2.ethg++ <--> Eth100M <--> host2.ethg++;

        // Conexões diretas entre router2 e os hosts internos
        //host1.ethg++ <--> Eth100M <--> router2.ethg++;
        //host2.ethg++ <--> Eth100M <--> router2.ethg++;
}
