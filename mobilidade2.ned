package inet.showcases.emulation.videostreaming;
import inet.node.ethernet.Eth100M;
import inet.node.inet.Router;
import inet.node.inet.StandardHost;
import inet.node.wireless.AccessPoint;
import inet.node.ethernet.EthernetSwitch;
import inet.networklayer.configurator.ipv4.Ipv4NetworkConfigurator;
import inet.visualizer.canvas.integrated.IntegratedCanvasVisualizer;
import inet.physicallayer.ieee80211.packetlevel.Ieee80211ScalarRadioMedium;
import inet.physicallayer.wireless.common.contract.packetlevel.IRadioMedium;
import inet.physicallayer.common.packetlevel.RadioMedium;
import inet.physicallayer.ieee80211.packetlevel.Ieee80211ScalarRadioMedium;


network Mobilidade2
{
    parameters:
        @display("bgb=1600,800");
    submodules:
        visualizer: IntegratedCanvasVisualizer {
            parameters:
                @display("p=100,100");
        }
        configurator: Ipv4NetworkConfigurator {
            parameters:
                @display("p=200,100");
        }
         radioMedium: <default("UnitDiskRadioMedium")> like IRadioMedium {
            @display("p=636,107");
        }
        host1: StandardHost {
            parameters:
                @display("p=100,600");
        }
        host2: StandardHost {
            parameters:
                @display("p=500,600");
        }
        ap1: AccessPoint {
            parameters:
                @display("p=300,400");
        }
        router: Router {
            parameters:
                @display("p=300,600");
        }
        switch1: EthernetSwitch {
            parameters:
                @display("p=200,600");
        }
    connections:
        host1.ethg++ <--> Eth100M <--> switch1.ethg++;
        switch1.ethg++ <--> Eth100M <--> router.ethg++;
        router.ethg++ <--> Eth100M <--> ap1.ethg++;
        host2.ethg++ <--> Eth100M <--> ap1.ethg++;
}
