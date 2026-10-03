#!/usr/bin/env python3
"""Geçerli XML'in bozuk model sözleşmelerini gizlemediğini sınar."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import xml.etree.ElementTree as ET

SPEC = importlib.util.spec_from_file_location("check_assets", Path(__file__).with_name("check-assets.py"))
CHECK = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CHECK)


class AssetCheckTests(unittest.TestCase):
    def test_expected_parser_cannot_silently_drop_animals_or_pets(self):
        original_read = CHECK.read
        for marker in ("ANIMAL_ORDER", "PET_SPECIES", 'id = "feed_quality"'):
            with self.subTest(marker=marker):
                with patch.object(CHECK, "read", side_effect=lambda path: original_read(path).replace(marker, "BROKEN_SCHEMA")):
                    with self.assertRaisesRegex(ValueError, "kapsamı okunamadı"):
                        CHECK.expected()

    def inspect(self, relative, mutate):
        source = CHECK.ROOT / relative
        root = ET.parse(source).getroot()
        mutate(root)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / source.name
            ET.ElementTree(root).write(path, encoding="utf-8", xml_declaration=True)
            return CHECK.inspect(path, source.parent.name)

    def test_real_moving_models_pass(self):
        for relative in ("client-assets/Birds/Gull.rbxmx", "client-assets/Fish/ReefFish.rbxmx",
                         "client-assets/Sea/Jellyfish.rbxmx", "client-assets/Sea/KelpBlade_A.rbxmx"):
            with self.subTest(relative=relative):
                self.assertEqual(self.inspect(relative, lambda root: None), [])

    def test_additional_top_level_script_is_rejected(self):
        problems = self.inspect("client-assets/Birds/Gull.rbxmx",
                                lambda root: ET.SubElement(root, "Item", {"class": "Script"}))
        self.assertTrue(any("üst düzey" in problem for problem in problems))

    def test_null_and_dangling_primary_part_are_rejected(self):
        for reference in ("null", "MISSING", "RBXMODEL"):
            with self.subTest(reference=reference):
                def mutate(root):
                    root.find("Item/Properties/Ref[@name='PrimaryPart']").text = reference
                problems = self.inspect("client-assets/Birds/Gull.rbxmx", mutate)
                self.assertTrue(any("PrimaryPart" in problem for problem in problems))

    def test_duplicate_referent_is_rejected(self):
        def mutate(root):
            parts = root.find("Item").findall("Item")
            parts[1].set("referent", parts[0].get("referent"))
        self.assertIn("yinelenen referent kimliği", self.inspect("client-assets/Birds/Gull.rbxmx", mutate))

    def test_wing_cannot_be_animation_pivot(self):
        def mutate(root):
            model = root.find("Item")
            wing = next(child for child in model.findall("Item")
                        if child.findtext("Properties/string[@name='Name']") == "LeftWing")
            model.find("Properties/Ref[@name='PrimaryPart']").text = wing.get("referent")
        self.assertTrue(any("animasyon pivotu" in problem for problem in self.inspect("client-assets/Birds/Gull.rbxmx", mutate)))

    def test_missing_wing_is_rejected(self):
        def mutate(root):
            model = root.find("Item")
            for child in model.findall("Item"):
                if child.findtext("Properties/string[@name='Name']") == "LeftWing":
                    model.remove(child)
        self.assertTrue(any("LeftWing" in problem for problem in self.inspect("client-assets/Birds/Gull.rbxmx", mutate)))

    def test_invalid_size_is_reported_without_crashing(self):
        for value in ("nan", "inf", "oops", "-1", "0"):
            with self.subTest(value=value):
                def mutate(root):
                    root.find("Item/Item/Properties/Vector3[@name='Size']/X").text = value
                self.assertTrue(any("Size" in problem for problem in self.inspect("client-assets/Birds/Gull.rbxmx", mutate)))

    def test_empty_pivot_is_rejected(self):
        def mutate(root):
            root.find("Item/Properties/OptionalCoordinateFrame[@name='WorldPivotData']").clear()
        self.assertTrue(any("pivot" in problem for problem in self.inspect("client-assets/Birds/Gull.rbxmx", mutate)))

    def test_surface_light_is_forbidden(self):
        def mutate(root):
            ET.SubElement(root.find("Item/Item"), "Item", {"class": "SurfaceLight"})
        self.assertIn("yasak sınıf: SurfaceLight", self.inspect("client-assets/Birds/Gull.rbxmx", mutate))

    def test_invalid_light_number_is_reported_without_crashing(self):
        def mutate(root):
            root.find(".//Item[@class='PointLight']/Properties/float[@name='Range']").text = "nan"
        self.assertTrue(any("Range" in problem for problem in self.inspect("client-assets/Sea/DiverChest.rbxmx", mutate)))


if __name__ == "__main__":
    unittest.main()
