from TestSim import TestSim

def main():
    # Get simulation ready to run.
    s = TestSim();

    # Before we do anything, lets simulate the network off.
    s.runTime(1);

    # Load the the layout of the network.
    s.loadTopo("tuna-melt.topo");

    # Add a noise model to all of the motes.
    s.loadNoise("no_noise.txt");

    # Turn on all of the sensors.
    s.bootAll();

    # Add the main channels. These channels are declared in includes/channels.h
    s.addChannel(s.COMMAND_CHANNEL);
    s.addChannel(s.GENERAL_CHANNEL);
    s.addChannel(s.TRANSPORT_CHANNEL);
    #s.addChannel(s.ROUTING_CHANNEL);

    # After sending a ping, simulate a little to prevent collision.
    s.runTime(200);
    s.testServer(1, 2);
    s.runTime(300);
    s.runTime(200);
    s.testServer(1, 3);
    s.runTime(300);
    #source, source socket, dest, dest socket, data
    s.testClient(2, 1, 1, 3, 25); #char value limit of 255 on transfer...
    s.runTime(200);
    s.testClient(4, 1, 1, 2, 25);
    s.runTime(200);
    #s.testClient(3, 4, 1, 1, 25);
#        s.testClient(4, 1, 1, 1, 30); #char value limit of 255 on transfer...
    s.runTime(300);
    s.testClientClose(2, 1, 1, 3);
    s.testClientClose(4, 1, 1, 2);
    s.runTime(800);
    #s.testClientClose(4, 1, 1, 2);



if __name__ == '__main__':
    main()
