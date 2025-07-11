package inet.showcases.emulation.videostreaming;

import inet.networklayer.configurator.ipv4.Ipv4NetworkConfigurator;
import inet.node.ethernet.Eth100M;
import inet.node.ethernet.EthernetSwitch;
import inet.node.inet.Router;
import inet.node.inet.StandardHost;
import inet.node.inet.AdhocHost;
import inet.visualizer.common.IntegratedVisualizer;
import inet.node.inet.WirelessHost;
import inet.node.wireless.AccessPoint;
import inet.physicallayer.wireless.ieee80211.packetlevel.Ieee80211ScalarRadioMedium;
import inet.environment.common.PhysicalEnvironment;
package inet.showcases.wireless.errorrate;

network VideoStreamingShowcase
{
    parameters:
        @display("bgb=1000,4000");
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
    connections:
        host1.ethg++ <--> Eth100M <--> switch1.ethg++;
        switch1.ethg++ <--> Eth100M <--> router.ethg++;
        router.ethg++ <--> Eth100M <--> switch2.ethg++;
        switch2.ethg++ <--> Eth100M <--> host2.ethg++;
}


network VideoStreamingShowcaseMobile
{
    parameters:
        @display("bgb=1000,4000");
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
                @display("p=750,299");
        }
        router: Router {
            parameters:
                @display("p=507,300");
        }
        routerMobile: Router {
            parameters:
                numWlanInterfaces = 1;  // adiciona uma interface wlan[0]
                @display("p=587,133");
                @display("i=misc/sensorgateway");
        }
        host1: StandardHost {
            parameters:
                @display("p=100,300");
        }
        host2: StandardHost {
            parameters:
                @display("p=900,300");
        }
        radioMedium: Ieee80211ScalarRadioMedium {
            parameters:
                @display("p=255,98");
        }
        ap1: AccessPoint {
            @display("p=398,75");
        }
        ap2: AccessPoint {
            @display("p=910,74");
        }
    connections:
        host1.ethg++ <--> Eth100M <--> switch1.ethg++;
        switch1.ethg++ <--> Eth100M <--> router.ethg++;
        switch2.ethg++ <--> Eth100M <--> host2.ethg++;

        routerMobile.ethg++ <--> Eth100M <--> switch2.ethg++;
        ap1.ethg++ <--> Eth100M <--> router.ethg++;
        ap2.ethg++ <--> Eth100M <--> ap1.ethg++;
}

network VideoStreamingShowcaseTwoMobiles
{
    parameters:
        @display("bgb=1000,4000");
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
                @display("p=750,299");
        }
        router: Router {
            parameters:
                @display("p=507,300");
        }
        routerMobile: Router {
            parameters:
                numWlanInterfaces = 1;  // adiciona uma interface wlan[0]
                @display("p=587,133");
                @display("i=misc/sensorgateway");
        }
        host1: StandardHost {
            parameters:
                @display("p=100,300");
        }
        host2: StandardHost {
            parameters:
                @display("p=900,300");
        }
        host3: WirelessHost {
            parameters:
                @display("p=922,164");
        }
        host4: StandardHost {
            parameters:
                @display("p=373,208");
        }
        radioMedium: Ieee80211ScalarRadioMedium {
            parameters:
                @display("p=255,98");
        }
        physicalEnvironment: PhysicalEnvironment {
            @display("p=580,425");
        }
        ap1: AccessPoint {
            @display("p=398,75");
        }
        ap2: AccessPoint {
            @display("p=910,74");
        }
    connections:
        host1.ethg++ <--> Eth100M <--> switch1.ethg++;
        switch1.ethg++ <--> Eth100M <--> router.ethg++;
        switch2.ethg++ <--> Eth100M <--> host2.ethg++;

        routerMobile.ethg++ <--> Eth100M <--> switch2.ethg++;
        ap1.ethg++ <--> Eth100M <--> router.ethg++;
        ap2.ethg++ <--> Eth100M <--> ap1.ethg++;

        host4.ethg++ <--> Eth100M <--> switch1.ethg++;
}

