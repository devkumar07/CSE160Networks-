from TestSim import TestSim

def main():
    # Get simulation ready to run.
    s = TestSim();

    # Before we do anything, lets simulate the network off.
    s.runTime(1);

    # Load the the layout of the network.
    s.loadTopo("tuna-melt.topo");

    # Add a noise model to all of the motes.
    s.loadNoise("meyer-heavy.txt");

    # Turn on all of the sensors.
    s.bootAll();

    # Add the main channels. These channels are declared in includes/channels.h
    s.addChannel(s.COMMAND_CHANNEL);
    s.addChannel(s.GENERAL_CHANNEL);
    s.addChannel(s.TRANSPORT_CHANNEL);
    #s.addChannel(s.ROUTING_CHANNEL);

    # After sending a ping, simulate a little to prevent collision.
    s.runTime(50);
    s.testServer(1, 2);
    s.runTime(60);
    s.runTime(50);
    s.testServer(2, 3);
    s.runTime(50);
    #source, dest, srcPort, destPort, data
    s.testClient(7, 2, 4, 3, 25); #char value limit of 255 on transfer...
    s.runTime(60);
    s.testClient(9, 1, 5, 2, 25);
    s.runTime(60);
    s.runTime(50);
    #src, dest, destPort, srcPort
    s.testClientClose(7, 2, 3, 4);
    s.runTime(60);
    s.runTime(60);
    s.testClientClose(9, 1, 2, 5);
    s.runTime(280);


if __name__ == '__main__':
    main()
