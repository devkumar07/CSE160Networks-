from TestSim import TestSim

def main():
    # Get simulation ready to run.
    s = TestSim();

    # Before we do anything, lets simulate the network off.
    s.runTime(1);

    # Load the the layout of the network.
    s.loadTopo("pizza.topo");

    # Add a noise model to all of the motes.
    s.loadNoise("no_noise.txt");

    # Turn on all of the sensors.
    s.bootAll();

    # Add the main channels. These channels are declared in includes/channels.h
    s.addChannel(s.COMMAND_CHANNEL);
    s.addChannel(s.GENERAL_CHANNEL);
    s.addChannel(s.TRANSPORT_CHANNEL);
    #s.addChannel(s.ROUTING_CHANNEL);

    """
    Format: call the function first and then the runTime
    """

    # After sending a ping, simulate a little to prevent collision.
    s.runTime(500);
    #s.testServer(1, 2);
    #s.runTime(200);
    #s.runTime(100);
    s.setServer(1,1);
    s.runTime(100);
    s.setClient(2,"hello devanshu 3\n");
    s.runTime(100);
    s.setClient(3,"hello keerthana 3\n");
    s.runTime(100);
    s.setClient(4,"hello John 3\n");
    s.runTime(100);
    s.setClient(2,"msg hello World!\n");
    s.runTime(100);
    s.setClient(2,"whisper keerthana hi!\n");
    s.runTime(300);
    s.setClient(2,"listusr\n");
    s.runTime(100);
    #s.setClient(3,"hello keerthana 3\n");
    #s.runTime(50);
    """
    s.testServer(8, 7);
    s.runTime(50);
    #s.testServer(6, 3);
    #s.runTime(50);

    #s.runTime(500);
    #source, dest, srcPort, destPort, data
    s.testClient(9, 8, 4, 7, 250); #char value limit of 255 on transfer...
    s.runTime(800);

    s.testClient(10, 8, 5, 7, 250);
    s.runTime(800);
    #src, dest, destPort, srcPort
    #s.testClientClose(9, 8, 7, 4);
    #s.runTime(200);
    #s.runTime(60);
    #s.testClientClose(10, 6, 3, 5);
    #s.runTime(280);
    """
if __name__ == '__main__':
    main()
