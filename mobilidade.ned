package inet.showcases.emulation.videostreaming;
import inet.node.ethernet.Eth100M;
import inet.networklayer.configurator.ipv4.Ipv4NetworkConfigurator;
import inet.node.inet.Router;
import inet.node.ethernet.EthernetSwitch;
import inet.node.inet.StandardHost;
import inet.node.wireless.AccessPoint;
import inet.node.inet.WirelessHost;
import inet.physicallayer.common.packetlevel.RadioMedium;
import inet.physicallayer.ieee80211.packetlevel.Ieee80211ScalarRadioMedium;
import inet.visualizer.canvas.integrated.IntegratedCanvasVisualizer;
import inet.physicallayer.wireless.common.contract.packetlevel.IRadioMedium;


network Mobilidade
{
    parameters:
        @display("bgb=2032,1057");
    submodules:
        configurator: Ipv4NetworkConfigurator {
            parameters:
                @display("p=100,100");
        }
        visualizer: IntegratedCanvasVisualizer {
            parameters:
                @display("p=384,99");
        }
        radioMedium: <default("UnitDiskRadioMedium")> like IRadioMedium {
            @display("p=636,107");
        }
        host1: StandardHost {
            parameters:
                @display("p=98,614");
        }
        ap1: AccessPoint {
            parameters:
                @display("p=814,608");
        }

        host2: WirelessHost {
            parameters:
                @display("p=1260,613");
        }
        switch1: EthernetSwitch {
            parameters:
                @display("p=286,611");
        }

        router: Router {
            parameters:
                @display("p=566,613");
        }



    connections:
        host1.ethg++ <--> Eth100M <--> switch1.ethg++;
        switch1.ethg++ <--> Eth100M <--> router.ethg++;      // 192.168.2.99
        router.ethg++ <--> Eth100M <--> ap1.ethg++;     // 192.168.3.99
  		host2.ethg++ <--> Eth100M <--> router.ethg++;






}

