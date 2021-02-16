#!/bin/bash
# Disable IRQ and set IRQ SMP affinity to core 0
if [[ -f /etc/init.d/irqbalance ]]; then
    /etc/init.d/irqbalance stop
fi
sleep 5
#set_irq_affinity_core_0
    #for all IRQ in /proc/irq/* ;
    for IRQDIR in `ls -d /proc/irq/*`;
    do
        if [ -d $IRQDIR ]; then
            echo f > $IRQDIR/smp_affinity 2>/dev/null
            cat $IRQDIR/smp_affinity
        fi
    done
exit 0
