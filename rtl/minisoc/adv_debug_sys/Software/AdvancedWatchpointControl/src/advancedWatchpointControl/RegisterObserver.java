////////////////////////////////////////////////////////////////
//
// RegisterObserver.java
//
// Copyright (C) 2010 Nathan Yawn 
//                    (nyawn@opencores.org)
//
// This interface is implemented by (display) classes that
// wish to be notified either when the register cache has
// changed due to an RSP read, or when their values should be
// written to the cache in preparation for an RSP write.
//
////////////////////////////////////////////////////////////////
//
// This source file may be used and distributed without
// restriction provided that this copyright statement is not
// removed from the file and that any derivative work contains
// the original copyright notice and the associated disclaimer.
// 
// This source file is free software; you can redistribute it
// and/or modify it under the terms of the GNU General
// Public License as published by the Free Software Foundation;
// either version 3.0 of the License, or (at your option) any
// later version.
//
// This source is distributed in the hope that it will be
// useful, but WITHOUT ANY WARRANTY; without even the implied 
// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
// PURPOSE.  See the GNU Lesser General Public License for more
// details.
// 
// You should have received a copy of the GNU General
// Public License along with this source; if not, download it 
// from http://www.gnu.org/licenses/gpl.html
//
////////////////////////////////////////////////////////////////
package advancedWatchpointControl;

public interface RegisterObserver {
	public enum updateDirection { GUI_TO_REGS, REGS_TO_GUI }
	
	void notifyRegisterUpdate(updateDirection dir) throws NumberFormatException;
}
