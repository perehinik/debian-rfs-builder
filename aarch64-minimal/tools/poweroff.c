#include <stdio.h>
#include <stdlib.h>
#include <sys/reboot.h>
#include <unistd.h>

int main() {
    printf("Powering off the system...\n");

    sync();

    // Perform the poweroff system call
    reboot(RB_POWER_OFF);
    
    perror("Shutdown failed");
    return 1;
}
