module tb;
  initial begin
    test_main();
    $finish;
  end
  // A task to illustrate usage
  task test_main;
    // 1) Create base class object
    packet p1 = new();
    if (!p1.randomize()) begin
      $error("Randomization failed for p1");
    end
    p1.source = "BasePacket";
    p1.display();  // calls packet::display()
    // 2) Create derived class object
    ethernet_packet e1 = new();
    if (!e1.randomize()) begin
      $error("Randomization failed for e1");
    end
    e1.source = "EthDerived";
    e1.display();  // calls ethernet_packet::display()
  endtask // test_main
// Base Class
  class packet;
    // Randomizable fields
    rand int          id;
    rand bit [7:0]    payload[];
    // Non-random field
    string            source;
    // Constructor
    function new();
      id        = 0;
      source    = "UNKNOWN";
    endfunction : new
    // Constraints
    constraint payload_size_c {
      payload.size inside {[5:15]};
    }
    constraint id_range_c {
      id inside {[0:100]};
    }
    // ---- Virtual function so derived classes can override ----
    virtual function void display();
      $display("PACKET    : id=%0d, source=%s, payloadSize=%0d",
                id, source, payload.size());
    endfunction : display
  endclass : packet
// Derived Class
  class ethernet_packet extends packet;
    // Additional random fields
    rand bit [47:0] mac_src;
    rand bit [47:0] mac_dst;
    rand bit [15:0] eth_type;
    // Constraints
    constraint eth_type_c {
      eth_type inside {16'h0800, 16'h86DD}; // e.g. IPv4 or IPv6
    }
    // Override the display function
    function void display();
      $display("ETHERNET PKT: srcMAC=%h, dstMAC=%h, eth_type=0x%04h",
                mac_src, mac_dst, eth_type);
      // Then call parent's display to show id, source, etc.
      super.display();
    endfunction : display
  endclass : ethernet_packet
endmodule // tb