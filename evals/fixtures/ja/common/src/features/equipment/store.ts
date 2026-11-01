import { create } from "zustand";

export type Equipment = {
  id: string;
  name: string;
  department: string;
  borrowedBy: string | null;
};

type EquipmentState = {
  items: Equipment[];
  borrow: (id: string, userId: string) => void;
  giveBack: (id: string) => void;
};

export const useEquipmentStore = create<EquipmentState>((set) => ({
  items: [],
  borrow: (id, userId) =>
    set((s) => ({ items: s.items.map((e) => (e.id === id ? { ...e, borrowedBy: userId } : e)) })),
  giveBack: (id) =>
    set((s) => ({ items: s.items.map((e) => (e.id === id ? { ...e, borrowedBy: null } : e)) })),
}));
