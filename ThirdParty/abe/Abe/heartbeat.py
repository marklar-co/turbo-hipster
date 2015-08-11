# Copyright(C) 2011,2012,2013 by Abe developers.

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Affero General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see
# <http://www.gnu.org/licenses/gpl.html>.
"""
Abe heartbeat - a glorified logging layer designed to facilitate
real-time monitoring of Abe in production environments. This module
is meant to be used as a Singleton. Note that this means it's
not meant to be used in a multi-process environment - if there's
any sign of the subprocessing module, be mindful of this.

Utilizes a RotatingFileHandler with maxBytes=4MB and backupCount=2
with sample output as follows:

[26653] [Abe.heartbeat] [2015-08-11 10:33:30,999] [INFO] - rpc for chain 18

The first field is PID.
"""

import logging
import logging.handlers
import os
import time

# pre-defined messages
NORMAL_SHUTDOWN_MSG = "ABE HEARBEAT NORMAL SHUTDOWN"
HELLO_WORLD_MSG = "ABE HEARBEAT HELLO WORLD"

# for rate limiting
MSGS_PER_SEC = 3

# implementation follows...

logger = logging.getLogger(__name__)
logger.propagate = False
logger.setLevel(logging.DEBUG)

initialized = False


class _RateLimiter(object):
    def __init__(self, rate):
        self.rate = rate
        self.last_accept_timestamp_s = None
        self.budget_remaining = self.rate
        self.current_drop_count = 0

    def should_accept(self):
        """
        Returns a (bool, int) for whether an "item" should
        "flow through", and a current count of "dropped" items.
        """
        time_now_s = int(time.time())
        time_elapsed = time_now_s - int(self.last_accept_timestamp_s or 0)
        self.last_accept_timestamp_s = time_now_s
        self.budget_remaining += time_elapsed * self.rate

        if self.budget_remaining > self.rate:
            self.budget_remaining = self.rate
        if self.budget_remaining < 1:
            self.current_drop_count += 1
            return False, self.current_drop_count
        else:
            self.budget_remaining -= 1
            ret_drop_count = self.current_drop_count
            self.current_drop_count = 0
            return True, ret_drop_count

rate_limiter = _RateLimiter(MSGS_PER_SEC)


def init(output_file):
    """
    Initialise output logging.
    """
    # create log base dir if needed
    log_dir_name = os.path.dirname(output_file)
    if not os.path.exists(log_dir_name):
        os.makedirs(log_dir_name)

    # set up logger
    handler = logging.handlers.RotatingFileHandler(output_file,
                                                   maxBytes=0x400000,
                                                   backupCount=2)
    handler.setLevel(logging.DEBUG)
    formatter = logging.Formatter("[%(process)d] [%(name)s] [%(asctime)s] [%(levelname)s] - %(message)s")
    handler.setFormatter(formatter)
    logger.addHandler(handler)

    # logger now ready
    global initialized
    initialized = True
    beep(HELLO_WORLD_MSG, lvl=logging.CRITICAL)


def beep(message, lvl=logging.DEBUG):
    """
    Log message, with rate limiting for DEBUG level messages.
    """
    global initialized
    if not initialized:
        return

    dropped_count = None

    if lvl == logging.DEBUG:
        global rate_limiter
        proceed, dropped_count = rate_limiter.should_accept()

        if not proceed:
            return
        elif dropped_count > 0:
            logger.log(logging.DEBUG, "({} messages dropped)".format(dropped_count))

    logger.log(lvl, message)


def normal_shutdown():
    """
    Convenience wrapper around 'beep' - as a convention call this only when the
    program is about to terminate normally, to indicate that termination was
    normal/graceful.
    """
    beep(NORMAL_SHUTDOWN_MSG, lvl=logging.CRITICAL)
